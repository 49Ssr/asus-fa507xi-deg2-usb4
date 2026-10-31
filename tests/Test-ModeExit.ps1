#requires -Version 5.1
# Mocked protocol/OS operations only. Temporary JSON files are the only real writes.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$researchRepo=Split-Path $PSScriptRoot -Parent
. (Join-Path $researchRepo 'tools\Capture-USB4PartnerSwap.ps1')
$script:checks=0
function Check([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message};$script:checks++}
function MustThrow([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Check $failed $Message}
function Write-Host {param($Object,$ForegroundColor)}
function Write-Warning {param($Message)}
function New-ItemProperty {throw 'Registry writes forbidden in tests'}
function Remove-ItemProperty {throw 'Registry writes forbidden in tests'}
function Restart-DeepUcsi {throw 'Device restart forbidden in tests'}
$testRoot=Join-Path $env:TEMP ('Usb4ModeExitTests-'+[guid]::NewGuid().ToString('N'))
$ownedRoot=[IO.Path]::GetFullPath($testRoot);$null=[IO.Directory]::CreateDirectory($ownedRoot)
function New-Reply([byte[]]$Bytes){return [pscustomobject]@{ProtocolResult='Completed';Bytes=$Bytes}}
function New-State {
    return [pscustomobject]@{
        Cap=(New-Reply ([byte[]]@(0x45,0x41,0,0,2,0xbd,0,0,1,0,0x20,1,0,2,0x10,1)))
        Connector=(New-Reply ([byte[]]@(0,0,0x4b,0x40,0x2c,0xb1,0x84,0x13,1)))
        Cam=(New-Reply ([byte[]]@(1)))
        Pdos=(New-Reply ([byte[]]@(0x2c,0x91,0x81,0x2f,0x2c,0xd1,2,0,0x2c,0xb1,4,0,0xe0,0x41,6,0)))
    }
}
function Assert-State($State){Assert-PartnerSwapModeExitState $State.Cap $State.Connector $State.Cam $State.Pdos}
try{
    $valid=New-State;Assert-State $valid;Check $true 'Captured target passes pure preflight'
    foreach($case in @('NoOverride','NoDetails','ShortCapability','Disconnected','PowerSource','UsbOnly','PartnerDfp','ShortStatus','CamZero','CamNone','MultipleCams','WrongPdos','BusyGet')){
        $state=New-State
        switch($case){
            NoOverride {$state.Cap.Bytes[5]=0xb5}
            NoDetails {$state.Cap.Bytes[5]=0xb9}
            ShortCapability {$state.Cap.Bytes=[byte[]]@(0)}
            Disconnected {$state.Connector.Bytes[2]=0x43}
            PowerSource {$state.Connector.Bytes[2]=0x5b}
            UsbOnly {$state.Connector.Bytes[2]=0x2b}
            PartnerDfp {$state.Connector.Bytes[3]=0x20}
            ShortStatus {$state.Connector.Bytes=[byte[]]@(0)}
            CamZero {$state.Cam.Bytes=[byte[]]@(0)}
            CamNone {$state.Cam.Bytes=[byte[]]@(255)}
            MultipleCams {$state.Cam.Bytes=[byte[]]@(0,1)}
            WrongPdos {$state.Pdos.Bytes[0]=0}
            BusyGet {$state.Cap.ProtocolResult='Busy'}
        }
        MustThrow {Assert-State $state} ('Refuse changed preflight: '+$case)
    }

    $script:nativeCalls=0;$script:replyKind='Good';$script:zeroReply=$false
    function Invoke-ProbeProcess {
        param($Executable,$Arguments,$Directory,$Timeout)
        Check ([IO.File]::Exists((Join-Path $Directory 'intent.json'))) 'Intent saved before native dispatch'
        $script:nativeCalls++
        $errorBit=if($script:replyKind -eq 'FirmwareError'){1}else{0}
        $busy=if($script:replyKind -eq 'Busy'){1}else{0}
        $length=if($script:zeroReply){0}else{1}
        $output=@('UCSI_CCI:','=========',('DataLength: '+$length),('ErrorIndicator: '+$errorBit),('BusyIndicator: '+$busy),'NotSupportedIndicator: 0','CommandCompletedIndicator: 1')
        if(-not $script:zeroReply){$output+=@('','UCSI MESSAGE_IN:','================',$(if($script:replyKind -eq 'BadLength'){'01 02'}else{'01'}),'')}
        [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stdout.txt'),($output -join [Environment]::NewLine))
        [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stderr.txt'),'')
        return $(if($script:replyKind -eq 'TransportError'){1}else{0})
    }
    $raw=Join-Path $ownedRoot 'raw';$null=[IO.Directory]::CreateDirectory($raw)
    $row=Invoke-PartnerSwapModeCommand $raw 'CURRENT' 0 0x0001000e
    Check ($row.ProtocolResult -eq 'Completed' -and $row.Bytes.Count -eq 1 -and $row.Bytes[0] -eq 1) 'Native GET bytes parsed'
    $script:zeroReply=$true;$row=Invoke-PartnerSwapModeCommand $raw 'EXIT' 0 0x0101000f -ExitReportedMode
    Check ($row.ProtocolResult -eq 'Completed' -and $row.Bytes.Count -eq 0) 'Zero-length completed EXIT reply valid'
    $count=$script:nativeCalls
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BAD1' 0 0x0181000f -ExitReportedMode} 'ENTER bit forbidden'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BAD2' 0 0x0102000f -ExitReportedMode} 'Other connector forbidden'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BAD3' 0 0x0001000f -ExitReportedMode} 'Other mode forbidden'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BAD4' 1 0x0101000f -ExitReportedMode} 'Nonzero mode-specific payload forbidden'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BAD5' 0 0x0101000f} 'State-changing command requires explicit exit path'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BAD6' 0 0x00010009} 'SET_UOR forbidden'
    Check ($count -eq $script:nativeCalls) 'Forbidden packets never reach transport'
    $script:zeroReply=$false;$script:replyKind='Busy'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'BUSY_GET' 0 0x0001000e} 'Busy GET stops the batch'
    $script:replyKind='BadLength'
    MustThrow {Invoke-PartnerSwapModeCommand $raw 'SHORT_GET' 0 0x0001000e} 'Length mismatch stops the batch'
    $script:zeroReply=$true;$script:replyKind='FirmwareError'
    $row=Invoke-PartnerSwapModeCommand $raw 'REFUSED_EXIT' 0 0x0101000f -ExitReportedMode
    Check ($row.ProtocolResult -eq 'FirmwareError') 'Firmware refusal is not success'

    # Actual workflow and guards, with device/network/trace/command operations mocked.
    $script:workflowCase='';$script:pnps=0;$script:traceStops=0;$script:sent=New-Object 'System.Collections.Generic.List[string]'
    function Get-PnpDevice {
        param([switch]$PresentOnly)
        $script:pnps++
        $devices=@([pscustomobject]@{Class='Display';Status='OK';FriendlyName='Internal';InstanceId='PCI\INTERNAL'})
        if($script:workflowCase -ne 'NoDock'){$devices+=[pscustomobject]@{Class='USBDevice';Status='OK';FriendlyName='DEG2';InstanceId='USB\VID_041F&PID_D002\MOCK'}}
        if($script:workflowCase -eq 'AlreadyWorking' -or ($script:workflowCase -eq 'Recovered' -and $script:pnps -gt 2) -or ($script:workflowCase -eq 'RecoveredBeforeExit' -and $script:pnps -gt 1)){$devices+=[pscustomobject]@{Class='USB';Status='OK';FriendlyName='Router';InstanceId='USB4\VID_8087&PID_5786\MOCK'}}
        if($script:workflowCase -eq 'Recovered' -and $script:pnps -gt 2){$devices+=[pscustomobject]@{Class='Display';Status='OK';FriendlyName='4080 SUPER';InstanceId='PCI\EXTERNAL'}}
        return $devices
    }
    function Get-DeepNetworkState {return @{MockOnly=$true}}
    function Get-DeepInterfaceState {return @{Present=$true;Value=1}}
    function Save-ConnectionInventory {param($Directory,$Phase)}
    function Test-DeepNativeInterface {param($Directory,[switch]$ExactInstance);Check ([bool]$ExactInstance) 'Exact native target requested'}
    function Start-ConnectionTrace {param($Directory);if($script:workflowCase -eq 'TraceStartFail'){throw 'Trace start failed'};return [ordered]@{Name='OWNED-MOCK';Stopped=$false}}
    function Stop-ConnectionTrace {param($Trace,$Directory);Check ($Trace.Name -eq 'OWNED-MOCK') 'Stop only own trace';$Trace.Stopped=$true;$script:traceStops++}
    function Start-Sleep {param($Seconds,$Milliseconds)}
    function Invoke-PartnerSwapModeCommand {
        param($Directory,$Name,$High,$Low,[switch]$ExitReportedMode)
        $script:sent.Add($Name);$state=New-State
        if($Name -eq 'GET_CAPABILITY'){if($script:workflowCase -eq 'NoOverride'){$state.Cap.Bytes[5]=0xb5};return $state.Cap}
        if($Name -like 'CONNECTOR*'){if($Name -eq 'CONNECTOR_AFTER' -and $script:workflowCase -eq 'AfterQueryFails'){throw 'Post-query failed'};return $state.Connector}
        if($Name -like 'CURRENT_MODE*'){if($Name -eq 'CURRENT_MODE_RECHECK' -and $script:workflowCase -eq 'ChangedMode'){$state.Cam.Bytes[0]=0};return $state.Cam}
        if($Name -like 'PARTNER_PDOS*'){return $state.Pdos}
        if($Name -eq 'EXIT_REPORTED_MODE'){
            Check ($ExitReportedMode -and $High -eq 0 -and $Low -eq 0x0101000f) 'Golden EXIT packet in actual workflow'
            $kind=switch($script:workflowCase){Rejected {'FirmwareError'};BusyExit {'Busy'};TransportExit {'TransportError'};default {'Completed'}}
            return [pscustomobject]@{ProtocolResult=$kind;Bytes=@()}
        }
        throw ('Unexpected command: '+$Name)
    }
    foreach($case in @('Normal','Recovered','RecoveredBeforeExit','NoDock','AlreadyWorking','NoOverride','ChangedMode','TraceStartFail','Rejected','BusyExit','TransportExit','AfterQueryFails')){
        $script:workflowCase=$case;$script:pnps=0;$script:traceStops=0;$script:sent.Clear()
        $dir=Join-Path $ownedRoot $case;$null=[IO.Directory]::CreateDirectory($dir)
        $result=Invoke-PartnerSwapModeExitTest $dir
        $exits=@($script:sent|Where-Object {$_ -eq 'EXIT_REPORTED_MODE'}).Count
        Check ($exits -le 1) ('At most one EXIT: '+$case)
        if($case -in @('NoDock','AlreadyWorking','NoOverride','ChangedMode','TraceStartFail','RecoveredBeforeExit')){Check ($exits -eq 0) ('Refused state sent no EXIT: '+$case)}
        if($case -eq 'RecoveredBeforeExit'){Check ($result.NewRouter -and -not $result.ModeExitRequested) 'Spontaneously recovered link preserved'}
        if($case -in @('Rejected','BusyExit','TransportExit')){Check ($result.Result -eq 'RejectedOrUncertain' -and $script:sent[-1] -eq 'EXIT_REPORTED_MODE') ('Rejected/uncertain exit stops all further commands: '+$case)}
        if($case -eq 'Recovered'){Check ($result.NewRouter -and $result.NewDisplays.Count -eq 1 -and $result.Result -eq 'Observed') 'Recovered milestones'}
        if($case -eq 'Normal'){Check (-not $result.NewRouter -and $result.NewDisplays.Count -eq 0 -and $result.Result -eq 'Observed') 'No recovery remains visible'}
        if($case -eq 'AfterQueryFails'){Check ($result.Result -eq 'ObservedWithQueryError' -and $script:sent[-1] -eq 'CONNECTOR_AFTER') 'Post-query failure stops commands and remains partial'}
        Check ([IO.File]::Exists((Join-Path $dir 'status.json'))) 'Status saved for every workflow case'
        if($case -notin @('NoDock','AlreadyWorking','NoOverride','TraceStartFail')){Check ($script:traceStops -eq 1) ('Owned trace stopped: '+$case)}
    }
    # The post-rejection read must not repeat EXIT or hide an empty/failed reply.
    $script:errorReadCase='';$script:errorReadCalls=0
    function Invoke-PartnerSwapModeCommand {
        param($Directory,$Name,$High,$Low,[switch]$ExitReportedMode)
        $script:errorReadCalls++
        Check ($Name -eq 'GET_ERROR_STATUS' -and $High -eq 0 -and $Low -eq 0x13 -and -not $ExitReportedMode) 'Only one error-status GET is allowed in the reader'
        if($script:errorReadCase -eq 'TransportFailure'){throw 'Native read failed'}
        $bytes=New-Object byte[] 16
        switch($script:errorReadCase){
            InvalidParameters {$bytes[0]=4}
            Multiple {$bytes[0]=0x18;$bytes[1]=8}
            Short {$bytes=[byte[]]@(4)}
        }
        return [pscustomobject]@{ProtocolResult='Completed';Bytes=$bytes}
    }
    foreach($case in @('Zero','InvalidParameters','Multiple','Short','TransportFailure')){
        $script:errorReadCase=$case;$script:errorReadCalls=0
        $dir=Join-Path $ownedRoot ('Error-'+$case);$null=[IO.Directory]::CreateDirectory($dir)
        $result=Invoke-PartnerSwapErrorRead $dir
        Check ($script:errorReadCalls -eq 1) ('Exactly one GET, no retries: '+$case)
        Check ([IO.File]::Exists((Join-Path $dir 'status.json'))) ('Error read status saved: '+$case)
        if($case -eq 'Zero'){Check ($result.Result -eq 'Recorded' -and $result.ErrorInformation -eq '0x0000' -and $result.ErrorNames.Count -eq 0 -and $result.Interpretation -match 'zero reply does not establish') 'Zero error is retained without a success claim'}
        if($case -eq 'InvalidParameters'){Check ($result.ErrorInformation -eq '0x0004' -and $result.ErrorNames[0] -eq 'Invalid command parameters') 'Error parameter bit decoded'}
        if($case -eq 'Multiple'){Check ($result.ErrorInformation -eq '0x0818' -and $result.ErrorNames.Count -eq 3 -and $result.ErrorNames -contains 'PPM policy conflict') 'Multiple error flags retained'}
        if($case -in @('Short','TransportFailure')){Check ($result.Result -eq 'Partial' -and $null -eq $result.ErrorInformation) ('Failed reader does not invent an error code: '+$case)}
    }
    Write-Output ('PASS '+$script:checks+' mode-exit/error-read guard/encoding/workflow checks in PowerShell '+$PSVersionTable.PSVersion+'. All hardware operations mocked.')
}finally{
    if([IO.Path]::GetFullPath($testRoot) -cne $ownedRoot -or -not $ownedRoot.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\Usb4ModeExitTests-',[StringComparison]::OrdinalIgnoreCase)){throw 'Test cleanup boundary failed'}
    Remove-Item -LiteralPath $ownedRoot -Recurse -Force -ErrorAction Stop
}
