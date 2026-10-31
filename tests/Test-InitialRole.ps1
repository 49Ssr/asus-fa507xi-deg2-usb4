#requires -Version 5.1
# Actual retained GET replies plus mocked firmware/ETW operations. No hardware SET.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$researchRepo=Split-Path $PSScriptRoot -Parent
. (Join-Path $researchRepo 'tools\Test-USB4InitialRole.ps1')
$script:checks=0
function Check([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message};$script:checks++}
function MustThrow([scriptblock]$Action,[string]$Message){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Check $failed $Message}
function Write-Host {param($Object,$ForegroundColor)}
function Write-Warning {param($Message)}
function New-ItemProperty {throw 'Registry writes forbidden in validation'}
function Restart-DeepUcsi {throw 'Device restarts forbidden in validation'}
$root=Join-Path ([IO.Path]::GetTempPath()) ('Usb4InitialRoleTests-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($root)
$script:InitialRoleState=Join-Path $root 'state.json'
function Reply([byte[]]$Bytes){return [pscustomobject]@{Bytes=$Bytes;ProtocolResult='Completed'}}
$script:cap=Reply ([byte[]]@(0x45,0x41,0,0,2,0xbd,0,0,1,0,0x20,1,0,2,0x10,1))
$script:con=Reply ([byte[]]@(0xa4,1))
$script:connected=Reply ([byte[]]@(0,0,0x4b,0x40,0x2c,0xb1,0x84,0x13,1))
$script:disconnected=Reply ([byte[]]@(0,0,0,0,0,0,0,0,0))
$script:pdos=Reply ([byte[]]@(0x2c,0x91,0x81,0x2f,0x2c,0xd1,2,0,0x2c,0xb1,4,0,0xe0,0x41,6,0))
try{
    $packet=Get-InitialRolePacket RP_ONLY
    Check ([BitConverter]::ToString([BitConverter]::GetBytes([uint64]$packet.Low)) -ceq '08-00-81-00-00-00-00-00') 'Rp-only packet matches independent UCSI bit positions'
    $packet=Get-InitialRolePacket DRP_DEFAULT
    Check ([BitConverter]::ToString([BitConverter]::GetBytes([uint64]$packet.Low)) -ceq '08-00-01-02-00-00-00-00') 'DRP packet matches independent UCSI bit positions'
    foreach($invalid in @('SET_UOR','RP_ONLY_C2','ENTER_CAM','RESET','')){MustThrow {Get-InitialRolePacket $invalid} 'Only named packets are accepted'}
    Assert-InitialRoleCapabilities $script:cap $script:con;Check $true 'Captured capabilities permit CC-mode test'
    Assert-InitialRoleTarget $script:connected $script:pdos;Check $true 'Captured DEG2 target passes'
    Assert-InitialRoleDisconnected $script:disconnected;Check $true 'Disconnected fixture passes'
    MustThrow {Assert-InitialRoleDisconnected $script:connected} 'Connected port refuses any CC-mode SET'
    foreach($invalid in @('NoCcom','WrongCount','ShortCapability','NoDrp','NoProvider','WrongPdos','DisconnectedTarget')){
        $c=Reply ([byte[]]$script:cap.Bytes.Clone());$k=Reply ([byte[]]$script:con.Bytes.Clone());$p=Reply ([byte[]]$script:pdos.Bytes.Clone());$s=Reply ([byte[]]$script:connected.Bytes.Clone())
        switch($invalid){NoCcom {$c.Bytes[5]=0xbc};WrongCount {$c.Bytes[4]=1};ShortCapability {$c.Bytes=[byte[]]@(0)};NoDrp {$k.Bytes[0]=0xa0};NoProvider {$k.Bytes[1]=0};WrongPdos {$p.Bytes[0]=0};DisconnectedTarget {$s.Bytes[2]=0}}
        if($invalid -in @('WrongPdos','DisconnectedTarget')){MustThrow {Assert-InitialRoleTarget $s $p} $invalid}else{MustThrow {Assert-InitialRoleCapabilities $c $k} $invalid}
    }
    # Exercise the parser with an actual retained reply, without sending it again.
    $capturedPath=Join-Path $researchRepo 'local\UcsiMemoryProbe\Runs\20261031-215802-ASUS-modes-25335372\Commands'
    $capturedQueries=Join-Path $researchRepo 'local\UcsiMemoryProbe\Runs\20261031-200759-deep-negotiation-254a4cf8\handoff\UCSI\ucsi-queries.json'
    $script:nativeCalls=0;$script:rawOutput=$null;$script:nativeExit=0
    function Invoke-ProbeProcess {param($Executable,$Arguments,$Directory,$Timeout)
        Check (Test-Path -LiteralPath (Join-Path $Directory 'intent.json')) 'Intent exists before native dispatch'
        $script:nativeCalls++
        [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stdout.txt'),$script:rawOutput)
        [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stderr.txt'),'')
        return $script:nativeExit
    }
    if(Test-Path -LiteralPath $capturedQueries){
        $captured=Get-Content -LiteralPath $capturedQueries -Raw|ConvertFrom-Json
        foreach($mapping in @(@('GET_CAPABILITY','CAPABILITY'),@('C1_CONNECTOR_CAPABILITY','CONNECTOR_CAPABILITY'),@('C1_CONNECTOR_STATUS','STATUS'),@('C1_PDOS_PARTNER_SOURCE','PARTNER_SOURCE'))){
            $item=@($captured|Where-Object {$_.Name -ceq $mapping[0]})
            Check ($item.Count -eq 1) 'One retained reply per fixture'
            $script:rawOutput=$item[0].Output
            $reply=Invoke-InitialRoleCommand $root ('FIXTURE_'+$mapping[1]) $mapping[1]
            Check ($reply.ProtocolResult -eq 'Completed' -and $reply.Bytes.Count -gt 0) 'Actual saved reply parses'
        }
    }else{Write-Output 'Private captured replies unavailable in this checkout; raw-reply fixture validation skipped.'}
    $script:rawOutput="UCSI_CCI:`r`nDataLength: 0`r`nErrorIndicator: 0`r`nBusyIndicator: 0`r`nNotSupportedIndicator: 0`r`nCommandCompletedIndicator: 1`r`n"
    $reply=Invoke-InitialRoleCommand $root 'MOCK_RP' RP_ONLY
    Check ($reply.Bytes.Count -eq 0) 'Completed SET must have zero reply bytes'
    foreach($fault in @('FirmwareError','Busy','Unsupported','Malformed','Transport')){
        $script:nativeExit=0
        $script:rawOutput="UCSI_CCI:`r`nDataLength: 0`r`nErrorIndicator: 0`r`nBusyIndicator: 0`r`nNotSupportedIndicator: 0`r`nCommandCompletedIndicator: 1`r`n"
        switch($fault){FirmwareError {$script:rawOutput=$script:rawOutput.Replace('ErrorIndicator: 0','ErrorIndicator: 1')};Busy {$script:rawOutput=$script:rawOutput.Replace('BusyIndicator: 0','BusyIndicator: 1')};Unsupported {$script:rawOutput=$script:rawOutput.Replace('NotSupportedIndicator: 0','NotSupportedIndicator: 1')};Malformed {$script:rawOutput='unparsed'};Transport {$script:nativeExit=1}}
        MustThrow {Invoke-InitialRoleCommand $root ('FAULT_'+$fault.ToUpperInvariant()) RP_ONLY} 'Noncompleted native request stops'
    }
    $calls=$script:nativeCalls
    MustThrow {Invoke-InitialRoleCommand $root 'DISALLOWED' RESET} 'Disallowed packet is rejected before dispatch'
    Check ($script:nativeCalls -eq $calls) 'No native call for a disallowed packet'

    # Lifecycle doubles exercise durable state, prompt ordering and restoration refusal.
    $script:commandLog=New-Object 'System.Collections.Generic.List[string]'
    $script:initialRoleTestCase='Good';$script:traceStarts=0;$script:traceStops=0
    function Invoke-InitialRoleCommand {param($Directory,$Record,$Name)
        $script:commandLog.Add($Record)
        if($script:initialRoleTestCase -eq 'FailedGet' -and $Record -eq 'CAPABILITY'){throw 'simulated GET failure'}
        if($Name -eq 'CAPABILITY'){return $script:cap}
        if($Name -eq 'CONNECTOR_CAPABILITY'){return $script:con}
        if($Name -eq 'PARTNER_SOURCE'){return $script:pdos}
        if($Name -eq 'RP_ONLY'){
            $saved=Get-Content -LiteralPath $script:InitialRoleState -Raw|ConvertFrom-Json
            Check $saved.RestoreRequired 'Pending restoration is durable before SET'
            if($script:initialRoleTestCase -eq 'RejectedSet'){throw 'simulated CCOM rejection'}
        }
        if($Record -eq 'OBSERVED_STATUS' -and $script:initialRoleTestCase -eq 'PostGetFailure'){throw 'simulated post GET failure'}
        if($Record -in @('DISCONNECTED_STATUS','RESTORE_DISCONNECTED_STATUS')){
            if($Record -eq 'RESTORE_DISCONNECTED_STATUS' -and $script:initialRoleTestCase -eq 'ConnectedCleanup'){return $script:connected}
            return $script:disconnected
        }
        return $script:connected
    }
    function Get-PnpDevice {param([switch]$PresentOnly,$ErrorAction)
        if($script:initialRoleTestCase -eq 'AlreadyRecovered'){return [pscustomobject]@{InstanceId='USB4\VID_8087&PID_5786\MOCK';Class='USB';Status='OK';FriendlyName='Mock router'}}
        return [pscustomobject]@{InstanceId='USB\VID_041F&PID_D002\MOCK';Class='USB';Status='OK';FriendlyName='Mock fallback'}
    }
    function Get-DeepNetworkState {return @{Synthetic=$true}}
    function Save-ConnectionInventory {param($Directory,$Phase)}
    function Test-DeepNativeInterface {param($Directory,[switch]$ExactInstance)}
    function Read-Host {param($Prompt);return ''}
    function Start-Sleep {param($Seconds,$Milliseconds)}
    function Start-ConnectionTrace {param($Directory);$script:traceStarts++;[IO.File]::WriteAllBytes((Join-Path $Directory 'connection.etl'),[byte[]]@(0));return @{Stopped=$false;Name='owned-mock'}}
    function Stop-ConnectionTrace {param($Trace,$Directory);Check ($Trace.Name -eq 'owned-mock') 'Only owned trace stops';$script:traceStops++;$Trace.Stopped=$true}
    foreach($case in @('Good','FailedGet','RejectedSet','PostGetFailure','ConnectedCleanup','StateWriteFailure','AlreadyRecovered')){
        $script:initialRoleTestCase=$case;$script:commandLog.Clear();$script:traceStarts=0;$script:traceStops=0
        $script:InitialRoleState=Join-Path $root 'state.json'
        if($case -eq 'StateWriteFailure'){$script:InitialRoleState=Join-Path $root 'state-is-a-directory';$null=[IO.Directory]::CreateDirectory($script:InitialRoleState)}
        $dir=Join-Path $root $case;$null=[IO.Directory]::CreateDirectory($dir)
        $result=Invoke-InitialRoleTest $dir
        if($case -eq 'Good'){
            Check $result.DefaultDrpRestored 'Normal completion restores default DRP'
            Check ($script:commandLog[$script:commandLog.Count-1] -eq 'RESTORE_DEFAULT_DRP') 'Restore is the last firmware request'
            Check ($script:traceStarts -eq 1 -and $script:traceStops -eq 1) 'Trace owned and stopped once'
        }elseif($case -eq 'FailedGet'){
            Check ($script:commandLog.Count -eq 1 -and -not $result.RpOnlyRequested) 'Failed preflight GET sends no later request'
            Check ($script:traceStarts -eq 0) 'No trace or SET after failed GET'
        }elseif($case -eq 'StateWriteFailure'){
            Check (-not $result.RpOnlyRequested -and -not $script:commandLog.Contains('REQUEST_RP_ONLY')) 'Unwritable durable state prevents SET'
            Check ($script:traceStops -eq 1) 'State-write failure closes the owned trace'
        }elseif($case -eq 'AlreadyRecovered'){
            Check ($script:commandLog.Count -eq 0 -and $script:traceStarts -eq 0) 'Recovered router is preserved without firmware traffic'
        }else{
            Check (-not $result.DefaultDrpRestored) 'Failure retains restoration requirement'
            Check (-not $script:commandLog.Contains('RESTORE_DEFAULT_DRP')) 'Uncertain or connected cleanup sends no automatic restore'
            Check ($script:traceStops -eq 1) 'Failure stops only the owned trace'
            $pending=Get-Content -LiteralPath $script:InitialRoleState -Raw|ConvertFrom-Json
            Check $pending.RestoreRequired 'Pending record survives failure'
            if($case -eq 'RejectedSet'){Check ($script:commandLog[$script:commandLog.Count-1] -eq 'REQUEST_RP_ONLY') 'No further GET or SET after rejected CC request'}
        }
    }
    Write-Output ('Initial-role validation passed: '+$script:checks+' assertions. Firmware/ETW operations mocked; no hardware test performed. Private temporary fixtures: '+$root)
}finally{
    # Keep the small test receipt for inspection; never recursively remove user paths.
}
