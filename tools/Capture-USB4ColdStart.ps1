#requires -Version 5.1
<# Post-startup observation only. No startup task, firmware request, device restart,
   driver installation, boot/security change or automatic shutdown/reboot. #>
[CmdletBinding()]
param([ValidateSet('Preview','Prepare','Collect')][string]$Mode='Preview',
      [string]$RunDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:ColdSource=$PSCommandPath
$script:ColdRoot=Join-Path (Split-Path $PSScriptRoot -Parent) 'local\ColdStart'

function Write-ColdJson([string]$Path,[object]$Value) {
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
}
function Assert-ColdPath([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    $root=[IO.Path]::GetFullPath($script:ColdRoot).TrimEnd('\')+'\'
    if(-not $full.StartsWith($root,[StringComparison]::OrdinalIgnoreCase)){throw 'Run must stay inside the private ColdStart folder.'}
    $item=$full
    while($item){
        if((Test-Path -LiteralPath $item) -and ((Get-Item -LiteralPath $item -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Reparse paths are not supported.'}
        $item=[IO.Path]::GetDirectoryName($item)
    }
    return $full
}
function Get-ColdPropertyData([object]$Property) {
    if($null -ne $Property.PSObject.Properties['Data']){return $Property.Data}
    if([string]$Property.Type -eq 'Empty'){return}
    throw 'PnP property data is unavailable with a nonempty type.'
}
function Get-ColdContext {
    $system=Get-CimInstance Win32_ComputerSystem
    $bios=Get-CimInstance Win32_BIOS
    if($system.Manufacturer -notmatch 'ASUS|ASUSTeK' -or $system.Model -notmatch '^ASUS TUF Gaming A15 FA507XI(?:_|$)' -or $bios.SMBIOSBIOSVersion -cne 'FA507XI.314'){
        throw 'This observation is prepared only for ASUS FA507XI BIOS 314.'
    }
    $uuid=[string](Get-CimInstance Win32_ComputerSystemProduct).UUID
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$machine=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($uuid)))).Replace('-','')}finally{$sha.Dispose()}
    $os=Get-CimInstance Win32_OperatingSystem
    $ucsi=Get-PnpDevice -InstanceId 'ACPI\USBC000\0' -PresentOnly -ErrorAction Stop
    if($ucsi.Status -cne 'OK'){throw 'The expected UCSI device is not healthy.'}
    $filters=@(Get-PnpDeviceProperty -InstanceId $ucsi.InstanceId -KeyName DEVPKEY_Device_LowerFilters,DEVPKEY_Device_UpperFilters -ErrorAction Stop)
    if(@($filters|ForEach-Object {Get-ColdPropertyData $_}|Where-Object {$_ -eq 'Usb4RolePolicy'}).Count){throw 'Experimental policy filter is still bound.'}
    $drivers=@(Get-CimInstance Win32_SystemDriver -Filter "Name='Usb4RolePolicy'")
    if(@($drivers|Where-Object {$_.State -eq 'Running'}).Count){throw 'Experimental policy driver is running.'}
    $packages=@(Get-WindowsDriver -Online -All -ErrorAction Stop|Where-Object {[IO.Path]::GetFileName([string]$_.OriginalFileName) -ieq 'Usb4RolePolicy.inf'})
    if($packages.Count){throw 'Experimental policy package is still installed.'}
    $base=Get-PnpDeviceProperty -InstanceId $ucsi.InstanceId -KeyName DEVPKEY_Device_DriverInfPath -ErrorAction Stop
    if([string]$base.Data -ine 'ucmucsiacpiclient.inf'){throw 'Expected Microsoft UCSI base package was not found.'}
    $security=[ordered]@{SecureBoot=$null;Error=$null}
    try{$security.SecureBoot=[bool](Confirm-SecureBootUEFI)}catch{$security.Error=$_.Exception.Message}
    return [pscustomobject]@{MachineHash=$machine;Model=$system.Model;Bios=$bios.SMBIOSBIOSVersion;Build=$os.BuildNumber;BootStamp=$os.LastBootUpTime.ToUniversalTime().ToString('o');BaseInf=$base.Data;Filters=$filters;Security=$security}
}
function Get-ColdDevices {
    return @(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {
        $_.Class -eq 'Display' -or $_.InstanceId -like 'USB4\*' -or
        $_.InstanceId -match '^USB\\VID_(8087|041F)|^ACPI\\PS8830'
    }|Select-Object Status,Class,FriendlyName,InstanceId)
}
function Get-ColdMilestones([object[]]$Devices) {
    return [pscustomobject]@{
        ExternalRouter=@($Devices|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786' -and $_.Status -eq 'OK'}).Count -gt 0
        GpuPresent=@($Devices|Where-Object {$_.InstanceId -match '^PCI\\VEN_10DE&DEV_2702' -and $_.Status -eq 'OK'}).Count -gt 0
        Billboard=@($Devices|Where-Object {$_.InstanceId -match '^USB\\VID_041F&PID_D002'}).Count -gt 0
    }
}
function Assert-ColdRecord([object]$Record,[object]$Context,[bool]$ForCollection) {
    if($Record.Kind -cne 'Usb4ColdStartObservation' -or $Record.MachineHash -cne $Context.MachineHash){throw 'Saved observation belongs to another machine or workflow.'}
    if($Record.SourceSHA256 -cne (Get-FileHash -LiteralPath $script:ColdSource).Hash){throw 'Observation source changed since preparation.'}
    $common=Join-Path $PSScriptRoot 'Usb4Capture.Common.ps1'
    if($Record.CommonSHA256 -cne (Get-FileHash -LiteralPath $common).Hash){throw 'Shared capture source changed since preparation.'}
    if($ForCollection -and $Record.BootStamp -ceq $Context.BootStamp){throw 'Windows has not started a new kernel session since preparation. Full shutdown/power-on is still required.'}
    if($ForCollection -and $Record.Phase -cne 'Prepared'){throw 'This observation has already been attempted. Preserve it; no automatic retry.'}
}
function Invoke-ColdStart([string]$Operation,[string]$Directory) {
    $context=Get-ColdContext
    if($Operation -eq 'Prepare'){
        if($Directory){throw 'Prepare creates its own private run directory.'}
        $Directory=Assert-ColdPath (Join-Path $script:ColdRoot ('run-'+[guid]::NewGuid().ToString('N')))
        $null=New-Item -ItemType Directory -Path $Directory
        $record=[ordered]@{Schema=1;Kind='Usb4ColdStartObservation';Phase='Prepared';MachineHash=$context.MachineHash;BootStamp=$context.BootStamp;SourceSHA256=(Get-FileHash -LiteralPath $script:ColdSource).Hash;CommonSHA256=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Usb4Capture.Common.ps1')).Hash;PreparedUtc=[DateTime]::UtcNow.ToString('o');Run=$Directory}
        Write-ColdJson (Join-Path $Directory 'preparation-context.private.json') $context
        Write-ColdJson (Join-Path $Directory 'devices-before.private.json') (Get-ColdDevices)
        Write-ColdJson (Join-Path $Directory 'run.private.json') $record
        Write-Host ('PREPARED: '+$Directory)
        return $Directory
    }
    if(-not $Directory){throw 'Collect requires the prepared RunDirectory. Use the generated collection launcher.'}
    $Directory=Assert-ColdPath $Directory
    $record=Get-Content -LiteralPath (Join-Path $Directory 'run.private.json') -Raw|ConvertFrom-Json
    Assert-ColdRecord $record $context $true
    if((Read-Host 'Was DEG2 powered ON and connected to the SAME ASUS USB4 port BEFORE pressing the ASUS power button, then left connected? Type PRECONNECTED') -cne 'PRECONNECTED'){throw 'Startup condition not confirmed; nothing was collected.'}
    $record.Phase='Collecting';Write-ColdJson (Join-Path $Directory 'run.private.json') $record
    $result=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');Result='Incomplete';PreconnectedOwnerConfirmed=$true;Context=$context;Snapshots=@();ExternalDisplay='Unknown';Trace=$null;Error=$null;Coverage='Post-sign-in only; no pre-OS/physical PD packet capture.'}
    $trace=$null
    try{
        $initial=Get-ColdDevices
        Write-ColdJson (Join-Path $Directory 'devices-after-startup.private.json') $initial
        $result.Snapshots+=Get-ColdMilestones $initial
        $trace=Start-ConnectionTrace $Directory
        Write-ColdJson (Join-Path $Directory 'trace-owner.private.json') $trace
        Write-Host 'Keep DEG2 connected and powered. Observing for 20 seconds; do not reconnect it.'
        Start-Sleep -Seconds 20
        $final=Get-ColdDevices
        Write-ColdJson (Join-Path $Directory 'devices-after-observation.private.json') $final
        $result.Snapshots+=Get-ColdMilestones $final
        $result.Result='Captured_RequiresAnalysis'
    }catch{$result.Error=$_.Exception.Message}
    finally{
        if($null -ne $trace){
            try{Stop-ConnectionTrace $trace $Directory}catch{$result.Error='Trace cleanup: '+$_.Exception.Message;$result.Result='Incomplete'}
            $result.Trace=$trace
            if(-not $trace.Stopped){$result.Result='OwnedTraceCleanupRequired'}
        }
        $record.Phase='Attempted';Write-ColdJson (Join-Path $Directory 'run.private.json') $record
        Write-ColdJson (Join-Path $Directory 'result.private.json') $result
    }
    if($result.Result -eq 'Captured_RequiresAnalysis'){
        $answer=Read-Host 'Image on the RTX 4080 SUPER display? Type Y, N or Unknown'
        if($answer -in @('Y','N','Unknown')){$result.ExternalDisplay=$answer}
        $result.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-ColdJson (Join-Path $Directory 'result.private.json') $result
    }
    Write-Host ('RESULT: '+$result.Result+'; evidence: '+$Directory)
    $result.Snapshots|Format-Table
    if($result.Error){Write-Warning $result.Error}
    return $result
}
if($MyInvocation.InvocationName -eq '.'){return}
if($Mode -eq 'Preview'){Write-Output 'Prepare records stock-driver state. Collect observes one owner-performed preconnected cold start with inventory and 20 seconds of passive ETW after sign-in. No automatic reboot or settings/firmware/device change.';return}
try{
    $admin=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run this observation in Administrator Windows PowerShell.'}
    . (Join-Path $PSScriptRoot 'Usb4Capture.Common.ps1')
    $null=Invoke-ColdStart $Mode $RunDirectory
}catch{Write-Error -Message $_.Exception.Message -ErrorAction Continue;exit 1}
