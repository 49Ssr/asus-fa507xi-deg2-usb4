[CmdletBinding()]
param(
    [ValidateSet('Preview','Read','Worker')][string]$Mode='Preview',
    [string]$RunDirectory,
    [string]$WorkerToken
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Split-Path $PSScriptRoot -Parent
$privateRoot=[IO.Path]::GetFullPath((Join-Path $repo 'local/BillboardStrings'))
function Wait-DEG2DescriptorWorker {
    param([System.Diagnostics.Process]$Process,[ValidateRange(1,45000)][int]$TimeoutMilliseconds=45000)
    if($Process.WaitForExit($TimeoutMilliseconds)) { return $true }
    # Use the retained process object, avoiding a second lookup by a reusable PID.
    try { $Process.Kill() } catch [System.InvalidOperationException] {
        if(-not $Process.HasExited) { throw }
    }
    $Process.WaitForExit(5000) | Out-Null
    return $false
}
if($Mode -eq 'Preview') {
    [pscustomobject]@{
        Status='Prepared_NotHardwareTested'; Device='041F:D002 revision8200'; Parent='1D5C:5801 revision0101'
        Reads='Fresh PnP binding; hub driver-key/connection metadata; standard BOS and strings0/7/8/9/10'
        Changes='None'; Limit='Information strings, not PD packets or a repair'; WorkerTimeoutSeconds=45
    }
    return
}
if($Mode -eq 'Read') {
    if($RunDirectory -or $WorkerToken) { throw 'Read does not accept a supplied path or worker token.' }
    $run=Join-Path $privateRoot ('run-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
    [IO.Directory]::CreateDirectory($run) | Out-Null
    $token=[guid]::NewGuid().ToString('N')
    $intent=[ordered]@{Schema=1;Token=$token;ParentPid=$PID;Script=[IO.Path]::GetFullPath($PSCommandPath);CreatedUtc=[DateTime]::UtcNow.ToString('o');Purpose='Standard descriptors only'}
    $intent | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'intent.private.json') -Encoding UTF8
    # Use literal PowerShell strings inside an encoded command, avoiding path parsing prompts.
    $scriptLiteral=$intent.Script.Replace("'","''"); $runLiteral=$run.Replace("'","''")
    $command="& '$scriptLiteral' -Mode Worker -RunDirectory '$runLiteral' -WorkerToken '$token'"
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $exe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $worker=Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-EncodedCommand',$encoded) -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $run 'worker.stdout.private.txt') -RedirectStandardError (Join-Path $run 'worker.stderr.private.txt')
    if(-not (Wait-DEG2DescriptorWorker -Process $worker)) {
        # Only this newly started helper is terminated. Windows closes its hub handle.
        @{Status='TimedOut_OutcomeUnknown';WorkerPid=$worker.Id;NoRetry=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'supervisor.private.json') -Encoding UTF8
        Write-Output "Stopped: descriptor worker timed out. Do not retry; evidence: $run"
        return
    }
    $resultPath=Join-Path $run 'result.private.json'
    if(-not (Test-Path -LiteralPath $resultPath)) { Write-Output "Stopped: no worker result. Evidence: $run"; return }
    $result=Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Write-Output ("Result: {0}; private evidence: {1}" -f $result.Status,$run)
    return
}
# Internal worker: runs only for an intent created by this script's Read mode.
$full=[IO.Path]::GetFullPath($RunDirectory)
if(-not $full.StartsWith($privateRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Worker path is outside private capture storage.' }
if([IO.Path]::GetFileName($full) -notmatch '^run-\d{8}-\d{6}-[0-9a-f]{32}$') { throw 'Invalid worker directory.' }
$intent=Get-Content -LiteralPath (Join-Path $full 'intent.private.json') -Raw | ConvertFrom-Json
if($WorkerToken -notmatch '^[0-9a-f]{32}$' -or $WorkerToken -cne $intent.Token -or $intent.Script -cne [IO.Path]::GetFullPath($PSCommandPath)) { throw 'Worker intent mismatch.' }
$process=Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$PID"
if([int]$process.ParentProcessId -ne [int]$intent.ParentPid) { throw 'Worker parent mismatch.' }
if(([DateTime]::UtcNow-[DateTime]::Parse($intent.CreatedUtc).ToUniversalTime()).TotalSeconds -gt 60) { throw 'Worker intent expired.' }
$result=[ordered]@{Schema=1;Status='Stopped_RequiresReview';StartedUtc=[DateTime]::UtcNow.ToString('o');HardwareTested=$false}
try {
    $model=(Get-CimInstance Win32_ComputerSystem).Model
    if($model -notmatch '(^|[^A-Z0-9])FA507XI([^A-Z0-9]|$)') { throw 'This collector is prepared only for ASUS FA507XI.' }
    $devices=@(Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^USB\\VID_041F&PID_D002\\' })
    if($devices.Count -ne 1) { throw 'Expected exactly one present DEG2 Billboard.' }
    $id=$devices[0].InstanceId
    function Property([string]$Instance,[string]$Key) {
        $v=Get-PnpDeviceProperty -InstanceId $Instance -KeyName $Key -ErrorAction Stop
        if($null -eq $v.Data) { throw "Unavailable property: $Key" }
        return $v.Data
    }
    $hardware=@(Property $id 'DEVPKEY_Device_HardwareIds')
    if($hardware -notcontains 'USB\VID_041F&PID_D002&REV_8200') { throw 'Billboard revision differs from retained capture.' }
    $parent=[string](Property $id 'DEVPKEY_Device_Parent')
    $parentHardware=@(Property $parent 'DEVPKEY_Device_HardwareIds')
    if($parentHardware -notcontains 'USB\VID_1D5C&PID_5801&REV_0101') { throw 'Parent hub revision/identity differs from retained capture.' }
    $address=Property $id 'DEVPKEY_Device_Address'
    if($address -isnot [uint32] -and $address -isnot [int]) { throw 'Port candidate is not numeric.' }
    $port=[uint32]$address
    $driver=[string](Property $id 'DEVPKEY_Device_Driver')
    # Address is only a candidate: native driver-key equality must confirm port ownership
    # before any descriptor GET. No scan or fallback guesses are permitted.
    $binding=[ordered]@{Instance=$id;Hardware=$hardware;Parent=$parent;ParentHardware=$parentHardware;PortCandidate=$port;DriverKey=$driver}
    $binding | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $full 'binding.private.json') -Encoding UTF8
    Add-Type -Path @((Join-Path $PSScriptRoot 'analysis/BillboardDescriptorProtocol.cs'),(Join-Path $PSScriptRoot 'analysis/BillboardHubReader.cs'))
    $capture=[Usb4Research.BillboardHubReader]::Capture($parent,$port,$driver,$full)
    $capture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $full 'strings.private.json') -Encoding UTF8
    $result.Status='Captured_RequiresAnalysis'; $result.HardwareTested=$true
    $result.StringCount=$capture.Strings.Count
} catch {
    $result.Error=$_.Exception.Message
} finally {
    $result.CompletedUtc=[DateTime]::UtcNow.ToString('o')
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $full 'result.private.json') -Encoding UTF8
}
