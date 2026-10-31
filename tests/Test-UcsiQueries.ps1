#requires -Version 5.1
# Synthetic replies only: no real PnP, registry, driver, firmware or ETW operations.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$researchRepo=Split-Path $PSScriptRoot -Parent
. (Join-Path $researchRepo 'tools\Capture-USB4PartnerSwap.ps1')
$script:checks=0
function Check([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message};$script:checks++}
function MustThrow([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Check $failed $Message}
function Write-Host {param($Object,$ForegroundColor)}
function Write-Warning {param($Message)}
function New-ItemProperty {throw 'Registry writes are forbidden in these tests'}
function Remove-ItemProperty {throw 'Registry writes are forbidden in these tests'}
function Restart-DeepUcsi {throw 'Device restarts are forbidden in these tests'}
function Set-DeepUcsiInterface {throw 'Preparation changes are forbidden in these tests'}
function Start-ConnectionTrace {throw 'ETW sessions are forbidden in these tests'}
$testRoot=Join-Path $env:TEMP ('Usb4QueryTests-'+[guid]::NewGuid().ToString('N'))
$ownedRoot=[IO.Path]::GetFullPath($testRoot)
$null=[IO.Directory]::CreateDirectory($ownedRoot)
$script:calls=New-Object 'System.Collections.Generic.List[object]'
$script:replyMode='Normal'
$script:connectors=1
$script:localModes=1
$script:helpText='Usage: UcsiControl.exe Send'+[Environment]::NewLine+'#1* ACPI\USBC000\0'
$script:helpExit=1
function Invoke-ProbeProcess {
    param($Executable,$Arguments,$Directory,$Timeout)
    if($Arguments[0] -eq '/?'){$output=$script:helpText;$code=$script:helpExit}
    else{
        $high=[Convert]::ToUInt32($Arguments[1],16);$low=[Convert]::ToUInt32($Arguments[2],16);$op=$low -band 255
        if($op -notin @(6,7,12,13,14,16,17,18,19)){throw 'A firmware write/reset reached the fake transport'}
        $script:calls.Add([pscustomobject]@{High=$high;Low=$low;Op=$op})
        $length=4;$code=0;$errorBit=0;$busy=0;$body=''
        if($op -eq 6){$length=16;$body='bNumConnectors: '+$script:connectors+[Environment]::NewLine+'bNumAltModes: '+$script:localModes}
        if($op -eq 12){$recipient=($low -shr 16) -band 7;$length=if($recipient -in @(0,1) -and ($high -lt 2 -or $script:replyMode -eq 'AllModes')){6}else{0}}
        if($script:replyMode -eq 'Busy' -and $op -eq 6){$busy=1}
        if($script:replyMode -eq 'TransportError' -and $op -eq 6){$code=1}
        if($script:replyMode -eq 'FirmwareError' -and $op -eq 7){$errorBit=1}
        $output=@('UCSI_CCI:','=========',('DataLength: '+$length),('BusyIndicator: '+$busy),('ErrorIndicator: '+$errorBit),'NotSupportedIndicator: 0','CommandCompletedIndicator: 1',$body) -join [Environment]::NewLine
    }
    [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stdout.txt'),$output)
    [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stderr.txt'),'')
    return $code
}
function New-CaseDirectory([string]$Name,[switch]$Uncreated){$path=Join-Path $ownedRoot $Name;if(-not $Uncreated){$null=[IO.Directory]::CreateDirectory($path)};return $path}
try{
    $script:UcsiInstance='ACPI\USBC000\0'
    $ready=New-CaseDirectory 'readiness'
    Test-DeepNativeInterface -Directory $ready -ExactInstance
    Check $true 'Actual CLI help convention accepts exit code 1 with exact single interface'
    $script:helpExit=0;Test-DeepNativeInterface -Directory $ready -ExactInstance;Check $true 'Help exit 0'
    $script:helpExit=2;MustThrow {Test-DeepNativeInterface -Directory $ready -ExactInstance} 'Other help exit refused'
    $script:helpExit=1;$script:helpText='Usage: UcsiControl.exe Send'+[Environment]::NewLine+'#1* ACPI\USBC000\1'
    MustThrow {Test-DeepNativeInterface -Directory $ready -ExactInstance} 'Wrong target refused'
    $script:helpText+=''+[Environment]::NewLine+'#2 ACPI\USBC000\0'
    MustThrow {Test-DeepNativeInterface -Directory $ready -ExactInstance} 'Multiple native interfaces refused'
    $script:helpText='No UCSI device found'
    MustThrow {Test-DeepNativeInterface -Directory $ready -ExactInstance} 'Unavailable native interface refused'

    $script:calls.Clear();$dir=New-CaseDirectory 'normal' -Uncreated
    $result=Invoke-Usb4FirmwareQueries $dir
    Check ($result.Completed -eq $result.CommandsAttempted -and -not $result.TransportFailedOrBusy) 'Normal query batch completes'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x0100000c -and $_.High -eq 1}).Count -eq 1) 'Read local offset 1 even when PPM reports one mode'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x0101000c -and $_.High -eq 1}).Count -eq 1) 'Read partner offset 1'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x0101000c -and $_.High -gt 2}).Count -eq 0) 'Stop partner list at empty response'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x0102000c -and $_.High -eq 0}).Count -eq 1) 'Cable SOP prime encoding'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x0103000c -and $_.High -eq 0}).Count -eq 1) 'Cable SOP double-prime encoding'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x00010010 -and $_.High -eq 7}).Count -eq 1) 'Local-source PDO golden encoding'
    Check (@($script:calls|Where-Object {$_.Low -eq 0x00810010 -and $_.High -eq 7}).Count -eq 1) 'Partner-source PDO golden encoding'
    $saved=Get-Content -LiteralPath (Join-Path $dir 'ucsi-queries.json') -Raw|ConvertFrom-Json
    Check ($saved.Count -eq $script:calls.Count -and $saved[0].Name -eq 'ERROR_STATUS_BEFORE_PROBES' -and $saved[-1].Name -eq 'ERROR_STATUS_AFTER_PROBES') 'Every raw reply and bracketing error-status query saved'
    $tokens=$null;$parseErrors=$null
    $dellAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $researchRepo 'tools\Capture-DellDEG2Control.ps1'),[ref]$tokens,[ref]$parseErrors)
    $wrapper=$dellAst.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-DellFirmwareQueries'},$true)
    . ([scriptblock]::Create($wrapper.Extent.Text))
    $script:calls.Clear();$dellResult=Invoke-DellFirmwareQueries (New-CaseDirectory 'dell-wrapper' -Uncreated)
    Check ($dellResult.Completed -eq $result.Completed -and $script:calls.Count -eq $saved.Count) 'Dell wrapper preserves the exercised shared query engine'
    $script:connectors=0;$script:calls.Clear();$result=Invoke-Usb4FirmwareQueries (New-CaseDirectory 'zero-connectors' -Uncreated)
    Check ($script:calls.Count -eq 3) 'Zero connectors issue no connector-specific commands'
    $script:replyMode='AllModes';$script:connectors=20;$script:localModes=20;$script:calls.Clear();$result=Invoke-Usb4FirmwareQueries (New-CaseDirectory 'bounded' -Uncreated)
    Check ($result.ConnectorsTruncated -and $result.ConnectorLimit -eq 8 -and $result.ModeOffsetLimit -eq 8) 'Enumeration limits reported'
    Check (@($script:calls|Where-Object {$_.Op -eq 12 -and (($_.Low -shr 24) -gt 8 -or $_.High -gt 7)}).Count -eq 0) 'No connector or mode outside bounds'
    $script:connectors=1;$script:localModes=1
    foreach($replyCase in @('Busy','TransportError')){
        $script:replyMode=$replyCase;$script:calls.Clear();$result=Invoke-Usb4FirmwareQueries (New-CaseDirectory $replyCase -Uncreated)
        Check ($result.TransportFailedOrBusy -and $script:calls.Count -eq 2) ($replyCase+' stops further firmware requests')
    }
    $script:replyMode='FirmwareError';$script:calls.Clear();$result=Invoke-Usb4FirmwareQueries (New-CaseDirectory 'firmware-error' -Uncreated)
    Check ($result.Completed -lt $result.CommandsAttempted -and -not $result.TransportFailedOrBusy) 'Firmware error is retained separately from transport failure'

    # Exercise the ASUS workflow with real result-file writes and mocked system reads.
    $script:workflowCalls=0;$script:hasDock=$true;$script:badInterface=$false;$script:queryThrows=$false;$script:partial=$false
    function Get-PnpDevice {param([switch]$PresentOnly);if($script:hasDock){[pscustomobject]@{InstanceId='USB\VID_041F&PID_D002\MOCK'}}}
    function Get-DeepInterfaceState {return [pscustomobject]@{Present=$true;Value=1}}
    function Get-DeepNetworkState {return @{MockOnly=$true}}
    function Save-ConnectionInventory {param($Directory,$Phase)}
    function Test-DeepNativeInterface {param($Directory,[switch]$ExactInstance);Check ([bool]$ExactInstance) 'ASUS workflow requests exact native target';if($script:badInterface){throw 'Wrong native target'}}
    function Invoke-Usb4FirmwareQueries {param($Directory);$script:workflowCalls++;if($script:queryThrows){throw 'Transport helper failed'};return @{Completed=1;CommandsAttempted=1;BudgetExpired=$false;TransportFailedOrBusy=$script:partial}}
    foreach($case in @('normal-workflow','no-dock','wrong-interface','query-exception','partial')){
        $script:hasDock=$case -ne 'no-dock';$script:badInterface=$case -eq 'wrong-interface';$script:queryThrows=$case -eq 'query-exception';$script:partial=$case -eq 'partial';$script:workflowCalls=0
        $dir=New-CaseDirectory $case;$result=Invoke-PartnerSwapModeInspection $dir
        $expected=if($case -eq 'normal-workflow'){'Recorded'}elseif($case -eq 'partial'){'Partial'}else{'NotCompleted'}
        Check ($result.Result -eq $expected) ('ASUS mode workflow: '+$case)
        Check (-not $result.RegistryWriteRequested -and -not $result.DeviceRestartRequested -and -not $result.FirmwareSetOrResetRequested) 'Read-only action declarations'
        Check ([IO.File]::Exists((Join-Path $dir 'status.json'))) 'Status saved on success/failure'
        if($case -in @('no-dock','wrong-interface')){Check ($script:workflowCalls -eq 0) 'Preflight failure sent no queries'}
    }
    Write-Output ('PASS '+$script:checks+' UCSI query/workflow checks in PowerShell '+$PSVersionTable.PSVersion+'. All native/system operations mocked.')
}finally{
    # Delete only this test's generated directory after checking its absolute boundary.
    if([IO.Path]::GetFullPath($testRoot) -cne $ownedRoot -or -not $ownedRoot.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\Usb4QueryTests-',[StringComparison]::OrdinalIgnoreCase)){throw 'Test cleanup boundary failed'}
    Remove-Item -LiteralPath $ownedRoot -Recurse -Force -ErrorAction Stop
}
