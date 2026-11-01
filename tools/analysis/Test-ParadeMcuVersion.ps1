#requires -Version 5.1
<# A single MCU-version read per bank in the EXISTING clean native-boot Windows.
   No CFU offers, flash helpers, driver/security/network/boot changes or reboot.
   Preview is the default. Test refuses the original Windows and any CFU package.
   Own handles close in finally; stop on the first failed operation, no retry. #>
[CmdletBinding()]
param([ValidateSet('Preview','Test')][string]$Mode='Preview',
      [string]$OutputRoot='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(-not $OutputRoot){$OutputRoot=Join-Path $PSScriptRoot 'VersionProbeResults'}
$script:ParadeTransportPin='FDA7CD887B0362F560BAA27D6062337A757DD13AAE98AF3283202B8DBAF738E9'

function Get-ParadeProbeContext {
    if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit Windows PowerShell.'}
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run as administrator.'}
    $system=Get-CimInstance Win32_ComputerSystem
    $bios=Get-CimInstance Win32_BIOS
    if($system.Manufacturer -notmatch 'ASUS|ASUSTeK' -or $system.Model -notmatch '^ASUS TUF Gaming A15 FA507XI(?:_|$)' -or $bios.SMBIOSBIOSVersion -cne 'FA507XI.314'){
        throw 'Only the reviewed FA507XI BIOS 314 is permitted.'
    }
    $driver=Join-Path $env:SystemRoot 'System32\drivers\PRSpbDrv.sys'
    if((Get-FileHash -LiteralPath $driver -Algorithm SHA256).Hash -cne 'A366FAFB3FE15F466D6CE0F302DCC5430B9964A6339CEAF10182AD0B94F8925C'){
        throw 'The reviewed original SPB driver is not installed.'
    }
    $cfu=@(Get-WindowsDriver -Online -All | Where-Object {[IO.Path]::GetFileName([string]$_.OriginalFileName) -ieq 'prcfudrv.inf'})
    $bound=@(Get-CimInstance Win32_PnPSignedDriver | Where-Object {$_.DeviceClass -eq 'FIRMWARE' -and $_.DriverProviderName -match 'Parade'})
    $boot=(& "$env:SystemRoot\System32\bcdedit.exe" /enum '{current}' /v | Out-String)
    if($LASTEXITCODE -ne 0){throw 'Current boot identity is unavailable.'}
    $isTestBoot=$boot -match '(?im)^device\s+vhd=' -and $boot -match '\\USB4-Test\.vhdx' -and $boot -match 'USB4 test - temporary Windows'
    foreach($id in @('ACPI\PS883011\1','ACPI\PS883021\1')){
        if((Get-PnpDevice -PresentOnly -InstanceId $id).Status -cne 'OK'){throw 'Required SPB endpoint is not healthy.'}
        $service=Get-PnpDeviceProperty -InstanceId $id -KeyName DEVPKEY_Device_Service
        if($service.Data -cne 'PRSpbDrv'){throw 'Unexpected endpoint binding.'}
    }
    $connected=@(Get-PnpDevice -PresentOnly | Where-Object {$_.InstanceId -match '^USB\\VID_041F&PID_D002|^USB4\\VID_8087&PID_5786'})
    $network=@(Get-NetAdapter -Physical | Where-Object {$_.Status -eq 'Up'})
    $os=Get-CimInstance Win32_OperatingSystem
    [pscustomobject]@{Model=$system.Model;Bios=$bios.SMBIOSBIOSVersion;Build=$os.BuildNumber;
        BootStamp=$os.LastBootUpTime.ToUniversalTime().ToString('o');IsExistingNativeTestBoot=[bool]$isTestBoot;
        ParadeCfuPackageCount=$cfu.Count;BoundParadeFirmwareCount=$bound.Count;
        ConnectedDeg2Count=$connected.Count;UpPhysicalNetworkCount=$network.Count;
        BootAgeMinutes=([DateTime]::Now-$os.LastBootUpTime).TotalMinutes;
        ReviewedSpbSHA256=(Get-FileHash -LiteralPath $driver).Hash}
}

function Assert-ParadeProbeReady([object]$Context) {
    if(-not $Context.IsExistingNativeTestBoot){throw 'Test requires the existing USB4 test - temporary Windows boot. Original Windows is refused.'}
    if($Context.ParadeCfuPackageCount -ne 0 -or $Context.BoundParadeFirmwareCount -ne 0){throw 'Parade CFU is present. Do not remove it here; this test is refused.'}
    if($Context.ConnectedDeg2Count -ne 0){throw 'Disconnect DEG2 and all USB-C cables before this version-only test.'}
    if($Context.UpPhysicalNetworkCount -ne 0){throw 'Keep this test Windows offline. Disconnect Ethernet and Wi-Fi manually.'}
    if($Context.BootAgeMinutes -lt 0 -or $Context.BootAgeMinutes -gt 30){throw 'Use a fresh test-Windows boot, within 30 minutes. No automatic reboot.'}
}

function Write-ParadeProbeJson([string]$Path,[object]$Value){
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding($false)))
}

$context=Get-ParadeProbeContext
if($Mode -eq 'Preview'){
    $readiness='Ready'
    try{Assert-ParadeProbeReady $context}catch{$readiness=$_.Exception.Message}
    [pscustomobject]@{Mode='Preview - no device opened';Context=$context;Readiness=$readiness} | ConvertTo-Json -Depth 5
    exit 0
}
Assert-ParadeProbeReady $context
$source=Join-Path $PSScriptRoot 'ParadeVersionProbe.cs'
if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw 'Missing reviewed version-only transport.'}
if((Get-FileHash -LiteralPath $source).Hash -cne $script:ParadeTransportPin){throw 'Version-only transport changed since review.'}
$root=[IO.Path]::GetFullPath($OutputRoot)
for($p=$root;$p;$p=[IO.Path]::GetDirectoryName($p)){
    if((Test-Path -LiteralPath $p) -and ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Linked output folders are refused.'}
}
if(Test-Path -LiteralPath $root){
    foreach($previous in @(Get-ChildItem -LiteralPath $root -File -Recurse -Filter 'result.private.json')){
        $saved=Get-Content -LiteralPath $previous.FullName -Raw|ConvertFrom-Json
        if($saved.Kind -cne 'ParadeMcuVersionOnly'){throw 'Unrecognised prior evidence in the output folder.'}
        if($saved.Phase -cne 'Prepared'){throw 'This kit already attempted a probe. Preserve the result; review is required before another test.'}
    }
}
$run=Join-Path $root ('run-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $run
$record=[ordered]@{Kind='ParadeMcuVersionOnly';Phase='Prepared';StartedUtc=[DateTime]::UtcNow.ToString('o');
    Context=$context;ScriptSHA256=(Get-FileHash -LiteralPath $PSCommandPath).Hash;
    TransportSHA256=(Get-FileHash -LiteralPath $source).Hash;Results=@();NoCfuOfferOrPayload=$true}
Write-ParadeProbeJson (Join-Path $run 'result.private.json') $record
Write-Host 'Version register only; no firmware update. Keep DEG2 and all USB-C cables disconnected.'
if((Read-Host 'Type DISCONNECTED to read each retimer version once') -cne 'DISCONNECTED'){throw 'Owner did not confirm disconnection.'}
# Recheck immediately before the first device open; no automatic retries.
Assert-ParadeProbeReady (Get-ParadeProbeContext)
Add-Type -Path $source
try{
    foreach($alias in @('PS883011','PS883021')){
        $record.Phase='Attempted_'+$alias
        Write-ParadeProbeJson (Join-Path $run 'result.private.json') $record
        $reply=[ParadeVersionProbe]::ReadVersion($alias)
        $record.Results+=@($reply)
        Write-ParadeProbeJson (Join-Path $run 'result.private.json') $record
        if($reply.Error -or -not $reply.HandleClosed){throw ('Stop after '+$alias+': '+$reply.Error)}
    }
    $record.Phase='VersionReadsRecorded_RequiresAnalysis'
}catch{
    $record.Phase='Stopped_NoRetry';$record.Error=$_.Exception.Message
}finally{
    $record.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    Write-ParadeProbeJson (Join-Path $run 'result.private.json') $record
}
Write-Host ('Result: '+$record.Phase+'; evidence: '+$run)
Write-Host 'Rollback: this program closed its own handles; it changed no persistent Windows setting. Return to your normal Windows manually.'
Write-Host 'Do not rerun this test. Keep the evidence, including any failure.'
