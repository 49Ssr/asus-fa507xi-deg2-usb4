#requires -Version 5.1
<# One explicitly selected FA507XI CC-mode experiment. No repair claim.
   Test requests Rp-only before attachment; RestoreDrp returns the connector to
   its documented reset/default DRP policy. Exact prior CC policy is not readable.
   No PPM reset, role-swap loop, CAM command, registry write or driver restart. #>
[CmdletBinding()]
param([ValidateSet('Preview','Test','RestoreDrp')][string]$Mode='Preview')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$initialRoleMode=$Mode
. (Join-Path $PSScriptRoot 'Capture-USB4PartnerSwap.ps1')
$script:InitialRoleState=Join-Path $privateRoot 'initial-role-test-state.json'

function Get-InitialRolePacket([string]$Name) {
    switch -Exact ($Name) {
        CAPABILITY {return [pscustomobject]@{High=[uint32]0;Low=[uint32]6;Set=$false}}
        CONNECTOR_CAPABILITY {return [pscustomobject]@{High=[uint32]0;Low=[uint32]0x00010007;Set=$false}}
        STATUS {return [pscustomobject]@{High=[uint32]0;Low=[uint32]0x00010012;Set=$false}}
        PARTNER_SOURCE {return [pscustomobject]@{High=[uint32]7;Low=[uint32]0x00810010;Set=$false}}
        RP_ONLY {return [pscustomobject]@{High=[uint32]0;Low=[uint32]0x00810008;Set=$true}}
        DRP_DEFAULT {return [pscustomobject]@{High=[uint32]0;Low=[uint32]0x02010008;Set=$true}}
        default {throw 'This experiment permits only four named GETs and connector-1 Rp-only/DRP CC-mode requests.'}
    }
}
function Invoke-InitialRoleCommand([string]$Directory,[string]$Record,[string]$Name) {
    $packet=Get-InitialRolePacket $Name
    if($Record -notmatch '^[A-Z0-9_]{1,48}$'){throw 'Invalid command record.'}
    $dir=Join-Path $Directory $Record
    $null=New-Item -ItemType Directory -Path $dir -ErrorAction Stop
    $row=[ordered]@{Name=$Name;High=$packet.High.ToString('X8');Low=$packet.Low.ToString('X8');StateChanging=$packet.Set;StartedUtc=[DateTime]::UtcNow.ToString('o');ProtocolResult='NotSent';ExitCode=$null;Output='';Error='';Bytes=@()}
    Write-PartnerSwapJson (Join-Path $dir 'intent.json') $row
    try{
        $row.ExitCode=Invoke-ProbeProcess $script:UcsiTool @('Send',$row.High,$row.Low) $dir 5
        $row.Output=[IO.File]::ReadAllText((Join-Path $dir 'launcher-stdout.txt'))
        $row.Error=[IO.File]::ReadAllText((Join-Path $dir 'launcher-stderr.txt'))
        if($row.ExitCode -ne 0){$row.ProtocolResult='TransportError'}
        elseif($row.Output -match 'BusyIndicator:\s*1'){$row.ProtocolResult='Busy'}
        elseif($row.Output -match 'NotSupportedIndicator:\s*1'){$row.ProtocolResult='NotSupported'}
        elseif($row.Output -match 'ErrorIndicator:\s*1'){$row.ProtocolResult='FirmwareError'}
        elseif($row.Output -match 'CommandCompletedIndicator:\s*1' -and $row.Output -match 'ErrorIndicator:\s*0'){
            $length=[regex]::Match($row.Output,'(?s)UCSI_CCI:.*?DataLength:\s*(\d+)')
            if(-not $length.Success){throw 'CCI length unavailable.'}
            $message=[regex]::Match($row.Output,'(?s)UCSI MESSAGE_IN:\s*=+\s*(.*?)(?:\r?\n\r?\n|$)')
            $bytes=@();if($message.Success){$bytes=@([regex]::Matches($message.Groups[1].Value,'\b[0-9a-fA-F]{2}\b')|ForEach-Object {[Convert]::ToByte($_.Value,16)})}
            if($bytes.Count -ne [int]$length.Groups[1].Value){throw 'CCI length and returned bytes disagree.'}
            if($packet.Set -and $bytes.Count -ne 0){throw 'Unexpected CC-mode response data.'}
            $row.Bytes=$bytes;$row.ProtocolResult='Completed'
        }else{$row.ProtocolResult='Unparsed'}
    }catch{$row.ProtocolResult='TransportError';$row.Error=$_.Exception.Message}
    $row.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PartnerSwapJson (Join-Path $dir 'reply.json') $row
    if($row.ProtocolResult -ne 'Completed'){throw ($Name+': '+$row.ProtocolResult+'. No further firmware command is sent by this run. If restoration is pending, disconnect DEG2 and run RestoreDrp separately.')}
    return [pscustomobject]$row
}
function Assert-InitialRoleCapabilities([object]$Capability,[object]$Connector) {
    if($Capability.Bytes.Count -ne 16 -or $Capability.Bytes[4] -ne 2 -or ($Capability.Bytes[5] -band 1) -eq 0){throw 'Expected two-connector ASUS PPM with advertised SET_CCOM support.'}
    if($Connector.Bytes.Count -ne 2 -or ($Connector.Bytes[0] -band 4) -eq 0 -or ($Connector.Bytes[1] -band 1) -eq 0){throw 'Connector 1 must advertise DRP and provider capability.'}
}
function Assert-InitialRoleDisconnected([object]$Status) {
    if($Status.Bytes.Count -ne 9 -or ($Status.Bytes[2] -band 8) -ne 0){throw 'Connector 1 must be freshly verified disconnected before any CC-mode request.'}
}
function Assert-InitialRoleTarget([object]$Status,[object]$Pdos) {
    $expected=[byte[]]@(0x2c,0x91,0x81,0x2f,0x2c,0xd1,2,0,0x2c,0xb1,4,0,0xe0,0x41,6,0)
    if($Status.Bytes.Count -ne 9 -or ($Status.Bytes[2] -band 0x18) -ne 8 -or (($Status.Bytes[3] -shr 5) -band 7) -ne 2){throw 'Expected the captured DEG2 sink-power/host-data fallback state on connector 1.'}
    if($Pdos.Bytes.Count -ne $expected.Count -or [BitConverter]::ToString([byte[]]$Pdos.Bytes) -cne [BitConverter]::ToString($expected)){throw 'Partner source PDOs differ from the recorded DEG2 target.'}
}
function Assert-InitialRoleInputs {
    Assert-DeepHost
    if((Get-FileHash -LiteralPath (Join-Path $env:SystemRoot 'System32\drivers\UcmUcsiCx.sys') -Algorithm SHA256).Hash -cne '8F5122333060393180E6578CE22AA51C5D00B2165709EAA8262EA66FD6AFDD67'){throw 'UCSI class driver differs from the analyzed baseline.'}
    if((Get-FileHash -LiteralPath $script:UcsiTool -Algorithm SHA256).Hash -cne $script:UcsiToolHash){throw 'Native UCSI tool differs from the audited official package.'}
    $interface=Get-DeepInterfaceState
    if(-not $interface.Present -or $interface.Value -ne 1){throw 'The existing prepared diagnostic interface is required; this script will not enable or restart it.'}
}
function Read-InitialRoleState {
    $state=Get-Content -LiteralPath $script:InitialRoleState -Raw|ConvertFrom-Json
    if($state.Schema -ne 1 -or $state.Kind -ne 'FA507XIInitialRoleTest' -or $state.UcsiInstance -cne $script:UcsiInstance){throw 'Restoration record does not match this experiment.'}
    $machine=([Security.Principal.WindowsIdentity]::GetCurrent().User.AccountDomainSid).Value
    if($state.MachineSid -cne $machine){throw 'Restoration record belongs to another Windows installation.'}
    return $state
}
function Restore-InitialRoleDrp([object]$State,[string]$Directory) {
    if(-not $State.RestoreRequired){return $State}
    $null=Read-Host 'Disconnect DEG2 from ASUS connector 1. Press Enter only after disconnection to restore default DRP'
    $status=Invoke-InitialRoleCommand $Directory 'RESTORE_DISCONNECTED_STATUS' 'STATUS'
    Assert-InitialRoleDisconnected $status
    $null=Invoke-InitialRoleCommand $Directory 'RESTORE_DEFAULT_DRP' 'DRP_DEFAULT'
    # These fields exist before dispatch; replacement preserves the pending record if I/O fails.
    $State.RestoreRequired=$false;$State.Phase='DefaultDrpRestored';$State.RestoredUtc=[DateTime]::UtcNow.ToString('o')
    try{Write-PartnerSwapJson $script:InitialRoleState $State}catch{$State.RestoreRequired=$true;throw 'Default-DRP reply completed, but saving restoration state failed. Pending state was retained; inspect before another test.'}
    return $State
}
function Invoke-InitialRoleTest([string]$Directory) {
    $status=[ordered]@{Schema=1;Kind='FA507XIInitialRoleTestResult';Result='NotAttempted';RpOnlyRequested=$false;DefaultDrpRestored=$false;NewRouter=$false;NewDisplays=@();Error=$null;EvidenceErrors=@();NoRegistryDriverBootOrNetworkWrites=$true;LiveKernelHelperRequested=$false;OriginalCcPolicyReadable=$false;CoverageRequiresAnalysis=$true}
    $trace=$null;$state=$null
    try{
        $before=@(Get-PnpDevice -PresentOnly -ErrorAction Stop)
        if(@($before|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'}).Count){throw 'DEG2 router is already present; preserve the recovered connection.'}
        if(-not @($before|Where-Object {$_.InstanceId -match '^USB\\VID_041F&PID_D002'}).Count){throw 'Start with powered DEG2 connected in the recorded Billboard fallback state.'}
        Write-PartnerSwapJson (Join-Path $Directory 'network-before.private.json') (Get-DeepNetworkState)
        Save-ConnectionInventory $Directory 'before'
        Test-DeepNativeInterface -Directory (Join-Path $Directory 'InterfaceCheck') -ExactInstance
        $cap=Invoke-InitialRoleCommand $Directory 'CAPABILITY' 'CAPABILITY'
        $connector=Invoke-InitialRoleCommand $Directory 'CONNECTOR_CAPABILITY' 'CONNECTOR_CAPABILITY'
        Assert-InitialRoleCapabilities $cap $connector
        $current=Invoke-InitialRoleCommand $Directory 'TARGET_STATUS' 'STATUS'
        $pdos=Invoke-InitialRoleCommand $Directory 'TARGET_PDOS' 'PARTNER_SOURCE'
        Assert-InitialRoleTarget $current $pdos
        $null=Read-Host 'Leave DEG2 powered. Disconnect only its ASUS upstream cable. Press Enter when disconnected'
        $disconnected=Invoke-InitialRoleCommand $Directory 'DISCONNECTED_STATUS' 'STATUS'
        Assert-InitialRoleDisconnected $disconnected
        $trace=Start-ConnectionTrace $Directory
        $state=[pscustomobject]@{Schema=1;Kind='FA507XIInitialRoleTest';UcsiInstance=$script:UcsiInstance;MachineSid=([Security.Principal.WindowsIdentity]::GetCurrent().User.AccountDomainSid).Value;Run=$Directory;Phase='RpOnlyDispatchPending';RestoreRequired=$true;RestoredUtc=$null;RestoreMeaning='Return to documented reset/default DRP; exact pre-test CC policy cannot be read';StartedUtc=[DateTime]::UtcNow.ToString('o')}
        Write-PartnerSwapJson $script:InitialRoleState $state
        $status.RpOnlyRequested=$true
        $null=Invoke-InitialRoleCommand $Directory 'REQUEST_RP_ONLY' 'RP_ONLY'
        $state.Phase='RpOnlyAccepted';Write-PartnerSwapJson $script:InitialRoleState $state
        Write-Host 'GREEN: reconnect DEG2 to the SAME ASUS USB4 port now. Keep it connected for 30 seconds.' -ForegroundColor Green
        Start-Sleep -Seconds 30
        $after=@(Get-PnpDevice -PresentOnly -ErrorAction Stop)
        $ids=@($before|ForEach-Object InstanceId)
        $status.NewRouter=(@($after|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'}).Count -gt 0)
        $status.NewDisplays=@($after|Where-Object {$_.Class -eq 'Display' -and $ids -notcontains $_.InstanceId}|Select-Object Status,FriendlyName,InstanceId)
        Save-ConnectionInventory $Directory 'after-observation'
        $post=Invoke-InitialRoleCommand $Directory 'OBSERVED_STATUS' 'STATUS'
        if($post.Bytes.Count -ne 9){throw 'Malformed post-test connector status.'}
        $status.ConnectedAfterObservation=(($post.Bytes[2] -band 8) -ne 0)
        $status.PowerProviderAfterObservation=(($post.Bytes[2] -band 16) -ne 0)
        $status.PartnerTypeAfterObservation=(($post.Bytes[3] -shr 5) -band 7)
        $status.InitialRoleChangeRequiresTraceVerification=$true
        $status.Result=if($status.NewRouter){'RouterObserved_NotYetAValidatedFix'}elseif(-not $status.ConnectedAfterObservation){'NoAttachment_ChangedConditionNotEstablished'}else{'NoRouterObserved_TraceNeedsAnalysis'}
        Stop-ConnectionTrace $trace $Directory
        if(-not $trace.Stopped){throw 'Owned trace did not stop; inspect the saved session name.'}
        if(-not(Test-Path -LiteralPath (Join-Path $Directory 'connection.etl') -PathType Leaf)){throw 'Expected ETL is missing. Preserve pending restoration and use RestoreDrp separately.'}
        $status.EtlBytes=(Get-Item -LiteralPath (Join-Path $Directory 'connection.etl')).Length
        if($status.EtlBytes -ge 1GB){$status.EvidenceErrors+=@('ETL reached its cap; negotiation coverage may be incomplete.')}
        $state=Restore-InitialRoleDrp $state $Directory
        $status.DefaultDrpRestored=(-not $state.RestoreRequired)
    }catch{$status.Error=$_.Exception.Message;if($status.RpOnlyRequested -and $status.Result -eq 'NotAttempted'){$status.Result='RpOnlyRejectedOrUncertain'};Write-Warning $status.Error}
    finally{
        if($null -ne $trace){
            if(-not $trace.Stopped){try{Stop-ConnectionTrace $trace $Directory}catch{$status.EvidenceErrors+=@($_.Exception.Message)}}
            try{Write-PartnerSwapJson (Join-Path $Directory 'trace-status.json') $trace}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        }
        try{Write-PartnerSwapJson (Join-Path $Directory 'network-after.private.json') (Get-DeepNetworkState)}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        if($null -ne $state -and $state.RestoreRequired -and (Test-Path -LiteralPath $script:InitialRoleState)){Write-Warning 'Default DRP restoration remains pending. Disconnect DEG2 and run this script with -Mode RestoreDrp. Do not start another CC-mode test.'}
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-PartnerSwapJson (Join-Path $Directory 'status.json') $status
    }
    return $status
}

if($MyInvocation.InvocationName -eq '.'){return}
if($initialRoleMode -eq 'Preview'){
    Write-Output 'Unperformed experiment: one connector-1 SET_CCOM Rp-only request while disconnected, then one DEG2 attachment under bounded ETW.'
    Write-Output 'The hypothesis is to change the initial CC/data-role path, not disable Windows policy or force a guessed alternate mode.'
    Write-Output 'Start with powered DEG2 in its known ASUS fallback state. Read-only target/capability checks run first. No registry, driver, boot-security or network setting is written.'
    Write-Output 'Normal completion asks for disconnection, then restores documented default DRP. Exact pre-test CC policy is not readable. An interrupted/failed run can leave restoration pending; use RestoreDrp separately.'
    Write-Output 'No hardware command has been sent in Preview. Software validation is not a hardware result.'
    exit 0
}
Assert-InitialRoleInputs
if(Test-Path -LiteralPath $script:InitialRoleState){
    $previous=Read-InitialRoleState
    if($previous.RestoreRequired -and $initialRoleMode -eq 'Test'){throw 'A prior default-DRP restoration is pending. Disconnect DEG2 and use RestoreDrp first.'}
}elseif($initialRoleMode -eq 'RestoreDrp'){throw 'No restoration record exists; no command was sent.'}
if($initialRoleMode -eq 'RestoreDrp' -and -not $previous.RestoreRequired){Write-Output 'The recorded default-DRP restoration already completed. No command sent.';exit 0}
$run=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-ASUS-initial-role-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$null=New-Item -ItemType Directory -Path $run
if($initialRoleMode -eq 'RestoreDrp'){
    Test-DeepNativeInterface -Directory (Join-Path $run 'InterfaceCheck') -ExactInstance
    $restored=Restore-InitialRoleDrp $previous $run
    Write-Output ('Default DRP restored: '+(-not $restored.RestoreRequired)+'; private results: '+$run)
    exit 0
}
if((New-Object IO.DriveInfo([IO.Path]::GetPathRoot($repo))).AvailableFreeSpace -lt 3GB){throw 'Keep at least 3 GiB free for the bounded trace.'}
$result=Invoke-InitialRoleTest $run
Write-Output ('Initial-role result: '+$result.Result+'; default DRP restored: '+$result.DefaultDrpRestored+'; private results: '+$run)
if($null -ne $result.Error -or -not $result.DefaultDrpRestored -or $result.EvidenceErrors.Count){exit 1}
exit 0
