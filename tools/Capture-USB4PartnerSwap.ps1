#requires -Version 5.1
<# ASUS FA507XI negotiation investigation: full USB transfer ETW, current IFRs,
   and separately marked firmware-status queries. No firmware flash or driver patch. #>
[CmdletBinding()]
param(
    [ValidateSet('Preview','PrepareUcsi','Capture','InspectModes','TestModeExit','UndoUcsi')][string]$Mode='Preview',
    [ValidateSet('Compare','PeerHandoff','Direct')][string]$Scenario='Compare'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$swapRequestedMode=$Mode
$swapRequestedScenario=$Scenario
. (Join-Path $PSScriptRoot 'Usb4Capture.Common.ps1')
$script:UcsiInstance='ACPI\USBC000\0'
$script:UcsiKey='HKLM:\SYSTEM\CurrentControlSet\Enum\ACPI\USBC000\0\Device Parameters'
$script:UcsiState=Join-Path $privateRoot 'ucsi-test-interface-state.json'
$script:UcsiTool=Join-Path $toolRoot 'MUTT-UCSI\UcsiControl.exe'
$script:UcsiToolHash='22AC51EF4503E4FF3344B7C33FFB7509F43D26F5F4942A2C382DD91F4FB7B9A7'
$captureSymbolParent=Split-Path $repo -Parent
if([string]::IsNullOrWhiteSpace($captureSymbolParent)){$captureSymbolParent=$repo}
$script:DriverSymbols=Join-Path $captureSymbolParent 'USB4-Diagnostics\Symbols'
$script:DeepKd=Join-Path $repo 'local\WinDbg\extracted\amd64\kd.exe'

function Write-PartnerSwapJson([string]$Path,[object]$Value) {
    # Preserve the previous original-state record if a replacement is interrupted.
    $full=[IO.Path]::GetFullPath($Path)
    $temporary=Join-Path ([IO.Path]::GetDirectoryName($full)) ('.'+[IO.Path]::GetFileName($full)+'.'+[guid]::NewGuid().ToString('N')+'.tmp')
    try{
        $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($Value|ConvertTo-Json -Depth 12))
        $stream=New-Object IO.FileStream($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
        if([IO.File]::Exists($full)){[IO.File]::Replace($temporary,$full,[NullString]::Value)}else{[IO.File]::Move($temporary,$full)}
    }finally{if([IO.File]::Exists($temporary)){[IO.File]::Delete($temporary)}}
}
function Assert-DeepHost {
    if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit Windows PowerShell.'}
    $p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Use Administrator PowerShell.'}
    $model=[string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS').SystemProductName
    if($model -notmatch '(?i)(^|[^a-z0-9])FA507XI([^a-z0-9]|$)'){throw 'This firmware-interface workflow is scoped to ASUS FA507XI.'}
    $device=Get-PnpDevice -PresentOnly -InstanceId $script:UcsiInstance -ErrorAction Stop
    if($device.Status -ne 'OK'){throw 'The exact UCSI device is not healthy; preserve that state before continuing.'}
}
function Get-PartnerSwapPeer {
    $up=@(Get-NetAdapter -IncludeHidden -ErrorAction Stop|Where-Object {$_.InterfaceDescription -match 'USB4.*P2P' -and $_.Status -eq 'Up'})
    if($up.Count -ne 1){throw ('Expected exactly one Up USB4 P2P adapter; currently '+$up.Count+'. Connect ASUS directly to Dell and keep both awake.')}
    return $up[0]
}
function Get-DeepNetworkState {
    $manager=New-Object -ComObject HNetCfg.HNetShare
    $sharing=@($manager.EnumEveryConnection()|ForEach-Object {
        $p=$manager.NetConnectionProps($_);$c=$manager.INetSharingConfigurationForINetConnection($_)
        [pscustomobject]@{Name=$p.Name;Guid=[string]$p.Guid;Shared=[bool]$c.SharingEnabled;Type=$(if($c.SharingEnabled){[int]$c.SharingConnectionType}else{-1})}
    })
    return [ordered]@{
        Utc=[DateTime]::UtcNow.ToString('o')
        Adapters=@(Get-NetAdapter -IncludeHidden|Select-Object Name,InterfaceDescription,InterfaceGuid,ifIndex,Status)
        IP=@(Get-NetIPAddress|Select-Object InterfaceIndex,InterfaceAlias,AddressFamily,IPAddress,PrefixLength,PrefixOrigin)
        Interfaces=@(Get-NetIPInterface|Select-Object InterfaceIndex,InterfaceAlias,AddressFamily,Dhcp,InterfaceMetric)
        DNS=@(Get-DnsClientServerAddress|Select-Object InterfaceIndex,InterfaceAlias,AddressFamily,ServerAddresses)
        DefaultRoutes=@(Get-NetRoute|Where-Object {$_.DestinationPrefix -in @('0.0.0.0/0','::/0')}|Select-Object InterfaceIndex,DestinationPrefix,NextHop,RouteMetric)
        Sharing=$sharing
    }
}
function Get-DeepInterfaceState {
    $key=Get-Item -LiteralPath $script:UcsiKey -ErrorAction Stop
    $present=@($key.GetValueNames()) -contains 'TestInterfaceEnabled'
    if($present -and $key.GetValueKind('TestInterfaceEnabled').ToString() -ne 'DWord'){throw 'Existing TestInterfaceEnabled has an unexpected type; it was preserved.'}
    return [pscustomobject]@{Present=$present;Value=$(if($present){[long]$key.GetValue('TestInterfaceEnabled')}else{$null})}
}
function Restart-DeepUcsi {
    $output=& (Join-Path $env:SystemRoot 'System32\pnputil.exe') /restart-device $script:UcsiInstance 2>&1
    $code=$LASTEXITCODE
    if($code -eq 3010){throw 'UCSI restart requires a normal Windows Restart. Saved original registry state remains available for UndoUcsi.'}
    if($code -ne 0){throw ('UCSI device restart failed ('+$code+'): '+($output -join ' '))}
    for($i=0;$i -lt 20;$i++){
        $d=Get-PnpDevice -PresentOnly -InstanceId $script:UcsiInstance -ErrorAction Stop
        if($d.Status -eq 'OK'){return}
        Start-Sleep -Milliseconds 250
    }
    throw 'UCSI did not recover to OK within five seconds. Saved original state remains available for UndoUcsi.'
}
function Test-DeepInterfaceEqual([object]$Left,[object]$Right) {
    return ($Left.Present -eq $Right.Present -and (-not $Left.Present -or $Left.Value -eq $Right.Value))
}
function Test-DeepNativeInterface([string]$Directory=$null,[switch]$ExactInstance) {
    $dir=if([string]::IsNullOrWhiteSpace($Directory)){Join-Path $privateRoot 'UcsiInterfaceCheck'}else{$Directory}
    if(-not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir|Out-Null}
    $code=Invoke-ProbeProcess $script:UcsiTool @('/?') $dir 5
    $output=[IO.File]::ReadAllText((Join-Path $dir 'launcher-stdout.txt'))
    $output+=[Environment]::NewLine+[IO.File]::ReadAllText((Join-Path $dir 'launcher-stderr.txt'))
    if($output -match 'No UCSI device found|Failed to get UCSI device info'){
        throw ('The native UCSI test interface is not usable after restart. Details: '+$dir+'. Original setting is saved for UndoUcsi.')
    }
    if($output -notmatch 'UcsiControl\.exe.*Send|Usage:'){throw ('Native interface readiness was not established; inspect '+$dir)}
    if($ExactInstance){
        $devices=@([regex]::Matches($output,'(?m)^#\d+\*?\s+(ACPI\\[^\r\n]+)'))
        if($code -notin @(0,1) -or $devices.Count -ne 1 -or $devices[0].Groups[1].Value.Trim() -ine $script:UcsiInstance){throw 'Expected exactly the selected ASUS UCSI interface in native enumeration; no firmware queries were sent.'}
    }
    Write-PartnerSwapJson (Join-Path $dir 'status.json') ([ordered]@{Utc=[DateTime]::UtcNow.ToString('o');ExitCode=$code;InterfaceEnumerationFailed=$false;ReadinessCommand='/?';SendCommandIssued=$false})
}
function Set-DeepUcsiInterface([bool]$Undo) {
    Assert-DeepHost
    if($Undo){
        if(-not(Test-Path -LiteralPath $script:UcsiState)){throw 'No original-state record exists; nothing was changed.'}
        $saved=Get-Content -LiteralPath $script:UcsiState -Raw|ConvertFrom-Json
        if($saved.Machine -cne [Environment]::MachineName -or $saved.Instance -cne $script:UcsiInstance -or $saved.Key -cne $script:UcsiKey){throw 'Original-state record does not match this machine/device.'}
        if($saved.Stage -eq 'Restored'){Write-Output 'Original UCSI test-interface state is already restored.';return}
        $current=Get-DeepInterfaceState
        if(Test-DeepInterfaceEqual $current $saved.Original){
            if($saved.Stage -eq 'RegistryRestoredRestartPending'){Restart-DeepUcsi}
            $saved.Stage='Restored';Write-PartnerSwapJson $script:UcsiState $saved
            Write-Output 'Original setting is preserved; no registry overwrite was needed.'
            return
        }
        if(-not $current.Present -or $current.Value -ne 1){throw 'Current setting changed after preparation; preserved for review instead of overwriting it.'}
        if($saved.Original.Present){New-ItemProperty -LiteralPath $script:UcsiKey -Name TestInterfaceEnabled -PropertyType DWord -Value $saved.Original.Value -Force|Out-Null}
        else{Remove-ItemProperty -LiteralPath $script:UcsiKey -Name TestInterfaceEnabled -ErrorAction Stop}
        if(-not(Test-DeepInterfaceEqual (Get-DeepInterfaceState) $saved.Original)){throw 'Original registry-state verification failed; restart was not attempted.'}
        $saved.Stage='RegistryRestoredRestartPending';Write-PartnerSwapJson $script:UcsiState $saved
        Restart-DeepUcsi
        $saved.Stage='Restored';Write-PartnerSwapJson $script:UcsiState $saved
        Write-Output 'Original registry state restored and the same UCSI device restarted.'
        return
    }
    Assert-DeepTools
    $current=Get-DeepInterfaceState
    if(Test-Path -LiteralPath $script:UcsiState){
        $saved=Get-Content -LiteralPath $script:UcsiState -Raw|ConvertFrom-Json
        if($saved.Machine -cne [Environment]::MachineName -or $saved.Instance -cne $script:UcsiInstance -or $saved.Key -cne $script:UcsiKey){throw 'Existing original-state record is for another target.'}
        if($saved.Stage -eq 'Ready' -and $current.Present -and $current.Value -ne 0){Test-DeepNativeInterface;Write-Output 'UCSI test interface is already prepared. Original state was preserved.';return}
        throw 'A previous preparation record needs review or UndoUcsi; its original state was preserved.'
    }
    $driver=Join-Path $env:SystemRoot 'System32\drivers\UcmUcsiCx.sys'
    if((Get-FileHash -LiteralPath $driver -Algorithm SHA256).Hash -cne '8F5122333060393180E6578CE22AA51C5D00B2165709EAA8262EA66FD6AFDD67'){throw 'UCSI driver changed since its test-interface gate was audited; stop before modifying the setting.'}
    $network=Get-DeepNetworkState
    $saved=[ordered]@{Schema=1;Machine=[Environment]::MachineName;Instance=$script:UcsiInstance;Key=$script:UcsiKey;Original=$current;NetworkBefore=$network;CreatedUtc=[DateTime]::UtcNow.ToString('o');Stage='OriginalSaved'}
    Write-PartnerSwapJson $script:UcsiState $saved
    if(-not $current.Present -or $current.Value -eq 0){
        New-ItemProperty -LiteralPath $script:UcsiKey -Name TestInterfaceEnabled -PropertyType DWord -Value 1 -Force|Out-Null
        $saved.Stage='EnabledRestartPending';Write-PartnerSwapJson $script:UcsiState $saved
        Restart-DeepUcsi
    }
    $readback=Get-DeepInterfaceState
    if(-not $readback.Present -or $readback.Value -eq 0){throw 'Test-interface registry readback failed.'}
    Test-DeepNativeInterface
    $saved.Stage='Ready';Write-PartnerSwapJson $script:UcsiState $saved
    Write-Output 'UCSI test interface prepared on the existing Microsoft driver. No driver package was installed.'
    Write-Output 'Reconnect ASUS directly to Dell if its peer link dropped. Keep DEG2 powered. Then run -Mode Capture.'
    Write-Output 'Undo after examination: run this same script with -Mode UndoUcsi.'
}
function Assert-DeepTools {
    foreach($path in @($script:UcsiTool,$liveKd,$script:DeepKd,$script:DriverSymbols)){
        if(-not(Test-Path -LiteralPath $path)){throw ('Prepared tool/symbol input is missing: '+$path)}
    }
    if((Get-FileHash -LiteralPath $script:UcsiTool -Algorithm SHA256).Hash -cne $script:UcsiToolHash){throw 'Extracted official UcsiControl tool differs from the audited package member.'}
    $null=Assert-MicrosoftExecutable $liveKd 'Livekd64.exe'
    $null=Assert-MicrosoftExecutable $script:DeepKd 'kd.exe'
    if((Get-FileHash -LiteralPath $liveKd -Algorithm SHA256).Hash -cne 'E2884FA2BAA44A092FC7E8A6FE59FC02AF754FF18B1E10ECAEBD91A7097D5FB9'){throw 'LiveKD differs from the previously validated binary.'}
}
function New-DeepUcsiQueries {
    $queries=New-Object 'System.Collections.Generic.List[object]'
    $queries.Add([pscustomobject]@{Name='ERROR_STATUS_BEFORE_PROBES';High='00000000';Low='00000013'})
    $queries.Add([pscustomobject]@{Name='GET_CAPABILITY';High='00000000';Low='00000006'})
    foreach($connector in 1,2){
        $prefix=[uint32]($connector -shl 16)
        foreach($entry in @(@('CONNECTOR_STATUS',18),@('CONNECTOR_CAPABILITY',7),@('CABLE_PROPERTY',17),@('CAM_SUPPORTED',13),@('CURRENT_CAM',14))){
            $queries.Add([pscustomobject]@{Name=('C'+$connector+'_'+$entry[0]);High='00000000';Low=([uint32]($prefix -bor [uint32]$entry[1])).ToString('X8')})
        }
        foreach($role in @(@('LOCAL_SOURCE',7,0),@('LOCAL_SINK',3,0),@('PARTNER_SOURCE',7,8388608),@('PARTNER_SINK',3,8388608))){
            $queries.Add([pscustomobject]@{Name=('C'+$connector+'_PDOS_'+$role[0]);High=([uint32]$role[1]).ToString('X8');Low=([uint32]($prefix -bor 16 -bor [uint32]$role[2])).ToString('X8')})
        }
        $altBase=[uint32](($connector -shl 24) -bor 12)
        $queries.Add([pscustomobject]@{Name=('C'+$connector+'_ALT_LOCAL_0');High='00000000';Low=$altBase.ToString('X8')})
        foreach($repeat in 1,2,3){
            $queries.Add([pscustomobject]@{Name=('C'+$connector+'_ALT_PARTNER_0_REPEAT_'+$repeat);High='00000000';Low=([uint32]($altBase -bor 65536)).ToString('X8')})
        }
    }
    return $queries.ToArray()
}
function Invoke-DeepUcsiQueries([string]$Directory) {
    $rows=New-Object 'System.Collections.Generic.List[object]'
    $watch=[Diagnostics.Stopwatch]::StartNew()
    foreach($query in New-DeepUcsiQueries){
        if($watch.Elapsed.TotalSeconds -ge 60){break}
        if($query.High -notmatch '^[0-9A-F]{8}$' -or $query.Low -notmatch '^[0-9A-F]{8}$'){throw 'Malformed UCSI query plan.'}
        $opcode=[Convert]::ToUInt32($query.Low,16) -band 255
        if($opcode -notin @(6,7,12,13,14,16,17,18,19)){throw 'A non-query UCSI opcode was refused.'}
        $row=[ordered]@{Name=$query.Name;High=$query.High;Low=$query.Low;StartedUtc=[DateTime]::UtcNow.ToString('o');FinishedUtc=$null;ExitCode=$null;Output=$null;Error=$null;FirmwareReplyDecoded=$false}
        try{
            $row.ExitCode=Invoke-ProbeProcess $script:UcsiTool @('Send',$query.High,$query.Low) $Directory 5
            $row.Output=[IO.File]::ReadAllText((Join-Path $Directory 'launcher-stdout.txt'))
            $row.Error=[IO.File]::ReadAllText((Join-Path $Directory 'launcher-stderr.txt'))
        }catch{$row.Error=$_.Exception.Message}
        $row.FinishedUtc=[DateTime]::UtcNow.ToString('o');$rows.Add($row)
        Write-PartnerSwapJson (Join-Path $Directory 'ucsi-queries.json') @($rows.ToArray())
        if($null -eq $row.ExitCode -or ($row.Output+$row.Error) -match 'No UCSI device found|Failed to get UCSI device info'){break}
    }
    return [ordered]@{CommandsAttempted=$rows.Count;BudgetSeconds=60;ElapsedSeconds=$watch.Elapsed.TotalSeconds;CompletePlanAttempted=($rows.Count -eq @(New-DeepUcsiQueries).Count);RepliesRequireAnalysis=$true}
}
function Invoke-PartnerSwapModeInspection([string]$Directory) {
    $status=[ordered]@{Schema=1;Kind='ASUSModeInspection';StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotCompleted';Error=$null;Queries=$null;RegistryWriteRequested=$false;DeviceRestartRequested=$false;FirmwareSetOrResetRequested=$false}
    try{
        $dock=@(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786|^USB\\VID_8087&PID_5787|^USB\\VID_041F&PID_D002'})
        if($dock.Count -eq 0){throw 'Connect powered DEG2 to the ASUS USB4 port, wait for its notification, then run InspectModes again.'}
        Write-PartnerSwapJson (Join-Path $Directory 'interface-before.json') (Get-DeepInterfaceState)
        Write-PartnerSwapJson (Join-Path $Directory 'network-before.private.json') (Get-DeepNetworkState)
        Save-ConnectionInventory $Directory 'before'
        Test-DeepNativeInterface -Directory (Join-Path $Directory 'InterfaceCheck') -ExactInstance
        Write-Host 'Reading ASUS connector and alternate-mode tables. Keep DEG2 connected.' -ForegroundColor Cyan
        $queries=Join-Path $Directory 'UCSI'
        $status.Queries=Invoke-Usb4FirmwareQueries $queries
        $status.Result=if($status.Queries.TransportFailedOrBusy -or $status.Queries.BudgetExpired -or $status.Queries.Completed -ne $status.Queries.CommandsAttempted){'Partial'}else{'Recorded'}
    }catch{$status.Error=$_.Exception.Message;Write-Warning $status.Error}
    finally{
        try{Save-ConnectionInventory $Directory 'after'}catch{$status.InventoryAfterError=$_.Exception.Message}
        try{Write-PartnerSwapJson (Join-Path $Directory 'interface-after.json') (Get-DeepInterfaceState)}catch{$status.InterfaceAfterError=$_.Exception.Message}
        try{Write-PartnerSwapJson (Join-Path $Directory 'network-after.private.json') (Get-DeepNetworkState)}catch{$status.NetworkAfterError=$_.Exception.Message}
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-PartnerSwapJson (Join-Path $Directory 'status.json') $status
    }
    return $status
}
function Invoke-PartnerSwapModeCommand([string]$Directory,[string]$Name,[uint32]$High,[uint32]$Low,[switch]$ExitReportedMode) {
    if($Name -notmatch '^[A-Z0-9_]{1,48}$'){throw 'Invalid command record name.'}
    if($ExitReportedMode){
        if($High -ne 0 -or $Low -ne [uint32]0x0101000f){throw 'Only connector 1, reported mode 1, EXIT with zero mode-specific data is allowed.'}
    }elseif(($Low -band 255) -notin @(6,13,14,16,18,19)){throw 'This path permits only the required GET commands.'}
    $path=Join-Path $Directory $Name;New-Item -ItemType Directory -Path $path|Out-Null
    $row=[ordered]@{Name=$Name;High=$High.ToString('X8');Low=$Low.ToString('X8');ExitReportedMode=[bool]$ExitReportedMode;StartedUtc=[DateTime]::UtcNow.ToString('o');ExitCode=$null;ProtocolResult='NotSent';Output='';Error='';Bytes=@()}
    # An immutable per-command intent must be saved before native dispatch.
    Write-PartnerSwapJson (Join-Path $path 'intent.json') $row
    try{
        $row.ExitCode=Invoke-ProbeProcess $script:UcsiTool @('Send',$row.High,$row.Low) $path 5
        $row.Output=[IO.File]::ReadAllText((Join-Path $path 'launcher-stdout.txt'))
        $row.Error=[IO.File]::ReadAllText((Join-Path $path 'launcher-stderr.txt'))
        if($row.ExitCode -ne 0){$row.ProtocolResult='TransportError'}
        elseif($row.Output -match 'BusyIndicator: 1'){$row.ProtocolResult='Busy'}
        elseif($row.Output -match 'NotSupportedIndicator: 1'){$row.ProtocolResult='NotSupported'}
        elseif($row.Output -match 'ErrorIndicator: 1'){$row.ProtocolResult='FirmwareError'}
        elseif($row.Output -match 'CommandCompletedIndicator: 1' -and $row.Output -match 'ErrorIndicator: 0'){
            $row.ProtocolResult='Completed'
            $length=[regex]::Match($row.Output,'(?s)UCSI_CCI:.*?DataLength:\s*(\d+)')
            if(-not $length.Success){throw 'Missing CCI length.'}
            $message=[regex]::Match($row.Output,'(?s)UCSI MESSAGE_IN:\s*=+\s*(.*?)(?:\r?\n\r?\n|$)')
            $bytes=@();if($message.Success){$bytes=@([regex]::Matches($message.Groups[1].Value,'\b[0-9a-fA-F]{2}\b')|ForEach-Object {[Convert]::ToByte($_.Value,16)})}
            if($bytes.Count -ne [int]$length.Groups[1].Value){throw 'Reply byte count differs from CCI length.'}
            $row.Bytes=$bytes
        }else{$row.ProtocolResult='Unparsed'}
    }catch{$row.ProtocolResult='TransportError';$row.Error=$_.Exception.Message}
    $row.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PartnerSwapJson (Join-Path $path 'reply.json') $row
    if(-not $ExitReportedMode -and $row.ProtocolResult -ne 'Completed'){throw ('GET '+$Name+': '+$row.ProtocolResult+'. Further firmware commands stopped.')}
    return [pscustomobject]$row
}
function Assert-PartnerSwapModeExitState([object]$Capability,[object]$Connector,[object]$CurrentMode,[object]$PartnerPdos) {
    foreach($reply in @($Capability,$Connector,$CurrentMode,$PartnerPdos)){if($reply.ProtocolResult -ne 'Completed'){throw 'Every preflight GET must complete before a mode exit.'}}
    if($Capability.Bytes.Count -ne 16 -or ($Capability.Bytes[5] -band 12) -ne 12){throw 'PPM must explicitly advertise alternate-mode details and override support.'}
    if(($Capability.Bytes[4] -band 127) -lt 1 -or $Connector.Bytes.Count -ne 9){throw 'Unexpected connector/status layout.'}
    $flags=[BitConverter]::ToUInt32([byte[]]$Connector.Bytes,0)
    if(($flags -band 0x00080000) -eq 0 -or ($flags -band 0x00100000) -ne 0 -or (($flags -shr 21) -band 255) -ne 2 -or (($flags -shr 29) -band 7) -ne 2){throw 'Connector 1 must still be connected as sink with an alternate-mode-only UFP partner.'}
    if($CurrentMode.Bytes.Count -ne 1 -or $CurrentMode.Bytes[0] -ne 1){throw 'The previously observed current mode 1 is no longer present; preserve the new state.'}
    $pdoHex=($PartnerPdos.Bytes|ForEach-Object {([byte]$_).ToString('X2')}) -join ''
    if($pdoHex -cne '2C91812F2CD102002CB10400E0410600'){throw 'Connector 1 partner source PDOs no longer match the captured DEG2. No mode exit sent.'}
}
function Invoke-PartnerSwapModeExitTest([string]$Directory) {
    $status=[ordered]@{Schema=1;Kind='ASUSModeExitTest';StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotAttempted';Error=$null;EvidenceErrors=@();ModeExitRequested=$false;RegistryWriteRequested=$false;FirmwareImageWriteRequested=$false;DeviceRestartRequested=$false;ExitReply=$null;NewRouter=$false;NewDisplays=@();Recovery='Disconnect/reconnect DEG2 for normal automatic negotiation; no automatic mode re-entry is attempted.'}
    $trace=$null
    try{
        $before=@(Get-PnpDevice -PresentOnly -ErrorAction Stop)
        if(@($before|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'}).Count){throw 'DEG2 USB4 router is already present; preserve that state instead of changing modes.'}
        if(-not @($before|Where-Object {$_.InstanceId -match '^USB\\VID_041F&PID_D002'}).Count){throw 'Expected connected DEG2 Billboard fallback. Leave DEG2 connected to ASUS before this test.'}
        Write-PartnerSwapJson (Join-Path $Directory 'network-before.private.json') (Get-DeepNetworkState)
        Write-PartnerSwapJson (Join-Path $Directory 'interface-before.json') (Get-DeepInterfaceState)
        Save-ConnectionInventory $Directory 'before'
        Test-DeepNativeInterface -Directory (Join-Path $Directory 'InterfaceCheck') -ExactInstance
        $commands=Join-Path $Directory 'Commands';New-Item -ItemType Directory -Path $commands|Out-Null
        $cap=Invoke-PartnerSwapModeCommand $commands 'GET_CAPABILITY' 0 6
        $connector=Invoke-PartnerSwapModeCommand $commands 'CONNECTOR_BEFORE' 0 0x00010012
        $current=Invoke-PartnerSwapModeCommand $commands 'CURRENT_MODE_BEFORE' 0 0x0001000e
        $pdos=Invoke-PartnerSwapModeCommand $commands 'PARTNER_PDOS_BEFORE' 7 0x00810010
        Assert-PartnerSwapModeExitState $cap $connector $current $pdos
        Write-PartnerSwapJson (Join-Path $Directory 'plan.json') ([ordered]@{Connector=1;ReportedCurrentMode=1;EnterOrExit=0;ModeSpecificData=0;High='00000000';Low='0101000F';Meaning='Exit the currently reported mode once; do not select or enter another mode';CurrentModeMissingFromReportedLocalTable=$true})
        $trace=Start-ConnectionTrace $Directory
        Start-Sleep -Seconds 5
        # Re-check the target immediately before the single state-changing request.
        $connector=Invoke-PartnerSwapModeCommand $commands 'CONNECTOR_RECHECK' 0 0x00010012
        $current=Invoke-PartnerSwapModeCommand $commands 'CURRENT_MODE_RECHECK' 0 0x0001000e
        $pdos=Invoke-PartnerSwapModeCommand $commands 'PARTNER_PDOS_RECHECK' 7 0x00810010
        Assert-PartnerSwapModeExitState $cap $connector $current $pdos
        if(@(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'}).Count){$status.NewRouter=$true;$status.Result='RecoveredBeforeExit';throw 'DEG2 router appeared before the exit request; preserve the recovered link. No EXIT sent.'}
        $status.ModeExitRequested=$true
        Write-Host 'Requesting one exit from connector 1 current mode 1. Keep DEG2 connected during observation.' -ForegroundColor Yellow
        $status.ExitReply=Invoke-PartnerSwapModeCommand $commands 'EXIT_REPORTED_MODE' 0 0x0101000f -ExitReportedMode
        if($status.ExitReply.ProtocolResult -ne 'Completed'){$status.Result='RejectedOrUncertain';throw ('Mode-exit request: '+$status.ExitReply.ProtocolResult+'. No further firmware commands will be sent.')}
        Start-Sleep -Seconds 20
        $after=@(Get-PnpDevice -PresentOnly -ErrorAction Stop)
        $ids=@($before|ForEach-Object InstanceId)
        $status.NewRouter=(@($after|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'}).Count -gt 0)
        $status.NewDisplays=@($after|Where-Object {$_.Class -eq 'Display' -and $ids -notcontains $_.InstanceId}|Select-Object Status,Class,FriendlyName,InstanceId)
        Save-ConnectionInventory $Directory 'after-passive'
        $status.Result='Observed'
        $post=Invoke-PartnerSwapModeCommand $commands 'CONNECTOR_AFTER' 0 0x00010012
        if($post.ProtocolResult -eq 'Completed'){$null=Invoke-PartnerSwapModeCommand $commands 'CURRENT_MODE_AFTER' 0 0x0001000e}
    }catch{$status.Error=$_.Exception.Message;if($status.Result -eq 'Observed'){$status.Result='ObservedWithQueryError'};Write-Warning $status.Error}
    finally{
        if($null -ne $trace){
            try{Stop-ConnectionTrace $trace $Directory;if(-not $trace.Stopped){throw 'Owned trace did not stop.'}}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
            try{Write-PartnerSwapJson (Join-Path $Directory 'trace-status.json') $trace}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        }
        try{Save-ConnectionInventory $Directory 'final'}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        try{Write-PartnerSwapJson (Join-Path $Directory 'network-after.private.json') (Get-DeepNetworkState)}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        try{Write-PartnerSwapJson (Join-Path $Directory 'interface-after.json') (Get-DeepInterfaceState)}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-PartnerSwapJson (Join-Path $Directory 'status.json') $status
    }
    return $status
}
function New-DeepRecorderCommands {
    $tmf=Join-Path $script:DriverSymbols 'TMF'
    $images=@((Join-Path $env:SystemRoot 'System32'),(Join-Path $env:SystemRoot 'System32\drivers'))
    foreach($service in @('Usb4HostRouter','Usb4DeviceRouter')){
        $image=[string](Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$service)).ImagePath
        if($image.StartsWith('\SystemRoot\')){$image=Join-Path $env:SystemRoot $image.Substring(12)}
        if($image){$images+=[IO.Path]::GetDirectoryName($image)}
    }
    return @(
        '.symopt+0x400'
        ('.exepath '+(($images|Select-Object -Unique)-join ';'))
        '.echo USB4_DEEP_IFR_BEGIN'
        'dd nt!NtBuildNumber L1'
        '.reload /f WppRecorder.sys'
        '.load rcdrkd.dll'
        ('!rcdrkd.rcdrsearchpath '+$tmf)
        '!rcdrkd.rcdrloglist Usb4HostRouter Usb4DeviceRouter UcmUcsiCx UcmUcsiAcpiClient UcmCx'
        '!rcdrkd.rcdrlogdump Usb4HostRouter Usb4DeviceRouter UcmUcsiCx UcmUcsiAcpiClient UcmCx'
        ('!wdfkd.wdfsearchpath '+$tmf)
        '!wdfkd.wdflogdump UcmUcsiAcpiClient'
        '!wdfkd.wdflogdump UcmUcsiCx'
        '!wdfkd.wdflogdump Usb4HostRouter'
        '!usb4kd.usb4tree'
        '.echo USB4_DEEP_IFR_END'
        'q'
    )
}
function Invoke-DeepRecorders([string]$Directory) {
    $result=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');FinishedUtc=$null;ExitCode=$null;TranscriptCompleted=$false;Error=$null;HelperUnloadingVerified=$false;FirmwareMemoryReadRequested=$false}
    try{
        $commands=Join-Path $Directory 'recorders.wds'
        [IO.File]::WriteAllLines($commands,(New-DeepRecorderCommands),[Text.Encoding]::ASCII)
        $symbolRoot=(Join-Path $repo 'local\KernelDump\symbols-flat')+';'+$script:DriverSymbols+';'+(Join-Path $privateRoot 'symbols')
        $result.ExitCode=Invoke-ProbeProcess $liveKd @('-accepteula','-b','-k',$script:DeepKd,'-noshell','-ses','-cf',$commands) $Directory 60
        $text=[IO.File]::ReadAllText((Join-Path $Directory 'debugger.txt'))
        $result.TranscriptCompleted=($text.Contains('USB4_DEEP_IFR_BEGIN') -and $text.Contains('USB4_DEEP_IFR_END'))
        if(-not $result.TranscriptCompleted){$result.Error='Debugger did not reach both transcript markers.'}
    }catch{$result.Error=$_.Exception.Message}
    $result.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PartnerSwapJson (Join-Path $Directory 'recorders-status.json') $result
    return $result
}
function Save-DeepPhase([string]$Run,[string]$Name) {
    $phase=Join-Path $Run $Name;New-Item -ItemType Directory -Path $phase|Out-Null
    Save-ConnectionInventory $phase 'passive'
    Write-Host ('Reading current driver flight recorders: '+$Name) -ForegroundColor Cyan
    $ifrDir=Join-Path $phase 'IFR';New-Item -ItemType Directory -Path $ifrDir|Out-Null
    $ifr=Invoke-DeepRecorders $ifrDir
    $queriesDir=Join-Path $phase 'UCSI';New-Item -ItemType Directory -Path $queriesDir|Out-Null
    Write-Host ('Reading firmware-reported status after the passive window: '+$Name) -ForegroundColor Cyan
    $queries=Invoke-DeepUcsiQueries $queriesDir
    Save-ConnectionInventory $phase 'after-queries'
    $result=[ordered]@{Phase=$Name;CapturedUtc=[DateTime]::UtcNow.ToString('o');FlightRecorders=$ifr;FirmwareQueries=$queries}
    Write-PartnerSwapJson (Join-Path $phase 'phase-status.json') $result
    return $result
}
function Test-DeepNewGraphicsOrRouter([string]$Run,[string]$Phase) {
    $before=Get-Content -LiteralPath (Join-Path $Run 'devices-before.json') -Raw|ConvertFrom-Json
    $after=Get-Content -LiteralPath (Join-Path $Run ($Phase+'\devices-after-queries.json')) -Raw|ConvertFrom-Json
    if($before.Error -or $after.Error){return $false}
    $ids=@($before.Devices|ForEach-Object InstanceId)
    return @($after.Devices|Where-Object {
        ($_.Class -eq 'Display' -and $ids -notcontains $_.InstanceId) -or
        $_.InstanceId -match '^USB4\\VID_8087&PID_5786'
    }).Count -gt 0
}
function Invoke-PartnerSwapRecording([string]$Directory,[string]$CaptureScenario='Compare') {
    $status=[ordered]@{Schema=2;Kind='DeepNegotiationComparison';Scenario=$CaptureScenario;StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotCompleted';Error=$null;Markers=@();Phases=@();ControllerStayedAwake=$null;GpuWorking=$null;PhysicalSwitchTimesVerified=$false;FirmwareWirePacketsCaptured=$false;PayloadLimitPerUsbTransferBytes=4096;NewDeviceMilestoneObserved=$false}
    $trace=$null
    try{
        Write-PartnerSwapJson (Join-Path $Directory 'network-before.private.json') (Get-DeepNetworkState)
        Save-ConnectionInventory $Directory 'before'
        if($CaptureScenario -eq 'Direct'){$null=Read-Host 'Disconnect DEG2 USB-C from ASUS. Keep DEG2 powered. Press Enter when disconnected'}
        else{
            $ready=$false
            for($attempt=1;$attempt -le 3;$attempt++){
                $null=Read-Host 'Keep ASUS directly connected to Dell, both awake, DEG2 powered. Press Enter when the peer adapter is connected'
                try{$null=Get-PartnerSwapPeer;$ready=$true;break}catch{Write-Warning $_.Exception.Message}
            }
            if(-not $ready){throw 'Peer link never became ready; no trace or handoff was started.'}
        }
        $trace=Start-ConnectionTrace $Directory
        if($CaptureScenario -ne 'Direct'){
            Write-Host 'Recording the working peer for three seconds. Keep both cable ends attached.' -ForegroundColor Cyan
            Start-Sleep -Seconds 3;$null=Get-PartnerSwapPeer
            $status.Markers+=@{Name='InitialPeerBaselineEnd';Utc=[DateTime]::UtcNow.ToString('o')}
            $null=Read-Host 'Control negotiation: leave ASUS end attached; disconnect ONLY the Dell end. Press Enter when disconnected'
            $status.Markers+=@{Name='OwnerConfirmedPeerDisconnected';Utc=[DateTime]::UtcNow.ToString('o')}
            Start-Sleep -Seconds 10
            $status.Markers+=@{Name='PeerAttachPrompt';Utc=[DateTime]::UtcNow.ToString('o')}
            Write-Host 'GREEN: reconnect the free cable end to the SAME Dell Thunderbolt port now.' -ForegroundColor Green
            Start-Sleep -Seconds 25;$null=Get-PartnerSwapPeer
            $status.Markers+=@{Name='PeerPassiveEnd';Utc=[DateTime]::UtcNow.ToString('o')}
            $status.Phases+=Save-DeepPhase $Directory 'peer'
            $null=Get-PartnerSwapPeer
            $status.Markers+=@{Name='HandoffPrompt';Utc=[DateTime]::UtcNow.ToString('o')}
            Write-Host 'GREEN: leave ASUS end attached. Move ONLY the Dell end into powered DEG2 upstream now.' -ForegroundColor Green
            Start-Sleep -Seconds 25
            $status.Markers+=@{Name='HandoffPassiveEnd';Utc=[DateTime]::UtcNow.ToString('o')}
            $status.Phases+=Save-DeepPhase $Directory 'handoff'
            $status.NewDeviceMilestoneObserved=Test-DeepNewGraphicsOrRouter $Directory 'handoff'
        }
        if($CaptureScenario -eq 'Direct' -or ($CaptureScenario -eq 'Compare' -and -not $status.NewDeviceMilestoneObserved)){
            if($CaptureScenario -ne 'Direct'){$null=Read-Host 'Fresh-attach comparison: disconnect ONLY the ASUS cable end from DEG2. Press Enter when disconnected'}
            $status.Markers+=@{Name='OwnerConfirmedDisconnected';Utc=[DateTime]::UtcNow.ToString('o')}
            Start-Sleep -Seconds 10
            $status.Markers+=@{Name='FreshAttachPrompt';Utc=[DateTime]::UtcNow.ToString('o')}
            Write-Host 'GREEN: reconnect that ASUS cable end. The far end stays in powered DEG2 upstream.' -ForegroundColor Green
            Start-Sleep -Seconds 25
            $status.Markers+=@{Name='FreshAttachPassiveEnd';Utc=[DateTime]::UtcNow.ToString('o')}
            $status.Phases+=Save-DeepPhase $Directory 'fresh-attach'
        }
        elseif($status.NewDeviceMilestoneObserved){Write-Host 'A new display adapter or DEG2 router appeared. Keeping that connection for examination.' -ForegroundColor Green}
        $status.Result='Recorded'
    }catch{$status.Error=$_.Exception.Message;Write-Warning $status.Error}
    finally{
        if($null -ne $trace){
            try{Stop-ConnectionTrace $trace $Directory}catch{$trace.StopError=$_.Exception.Message;$status.Result='NotCompleted';$status.Error=$_.Exception.Message}
            if(-not $trace.Stopped){$status.Result='NotCompleted';$status.Error='Own ETW session did not stop normally: '+$trace.Name}
            Write-PartnerSwapJson (Join-Path $Directory 'trace-status.json') $trace
        }
        try{Write-PartnerSwapJson (Join-Path $Directory 'network-after.private.json') (Get-DeepNetworkState)}catch{$status.NetworkAfterError=$_.Exception.Message}
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        $etl=Join-Path $Directory 'connection.etl'
        $status.EtlPresent=Test-Path -LiteralPath $etl -PathType Leaf
        $status.EtlBytes=if($status.EtlPresent){(Get-Item -LiteralPath $etl).Length}else{0}
        $status.FileCapRisk=($status.EtlBytes -ge 1000MB)
        if($status.Result -eq 'Recorded' -and $status.EtlBytes -eq 0){$status.Result='NotCompleted';$status.Error='ETL is missing or empty.'}
        $status.CoverageRequiresAnalysis=$true
        Write-PartnerSwapJson (Join-Path $Directory 'status.json') $status
        Write-Host ('Private results: '+$Directory)
    }
    return $status
}

if($MyInvocation.InvocationName -eq '.'){return}
if($swapRequestedMode -eq 'Preview'){
    Write-Output 'PrepareUcsi saves original setting and network configuration, enables the documented UCSI test interface, and restarts only ACPI\USBC000\0.'
    Write-Output 'Capture requests full USB transfer/header data plus USB4/UCM/UCSI, ACPI, power, SPB and PnP/PCI traces in one sequential ETL capped at 1 GiB.'
    Write-Output 'Compare starts before a fresh Dell peer negotiation, then records handoff and (if no new graphics/router milestone) fresh DEG2 attach. Each phase reads current driver IFRs via signed LiveKD, then separately marked status queries via the official UcsiControl tool.'
    Write-Output 'Raw PD/CC wire packets are not supplied by this Windows stack. Requested providers, actual events, firmware replies and recorder formatting must be checked separately.'
    Write-Output 'UndoUcsi restores the exact saved setting and restarts the same UCSI device. No network settings, driver package, boot security or firmware image is changed.'
    Write-Output 'InspectModes reads the already-connected DEG2 mode table with the existing prepared UCSI interface. It uses the Dell-tested bounded GET engine and saves before/after snapshots.'
    Write-Output 'TestModeExit checks the observed DEG2 state and advertised mode-override support, then requests a single exit from current mode 1 on connector 1 while tracing. Reconnect DEG2 for ordinary automatic negotiation afterward if needed.'
    exit 0
}
Assert-DeepHost
if($swapRequestedMode -eq 'PrepareUcsi'){Set-DeepUcsiInterface $false;exit 0}
if($swapRequestedMode -eq 'UndoUcsi'){Set-DeepUcsiInterface $true;exit 0}
Assert-DeepTools
$interface=Get-DeepInterfaceState
if(-not $interface.Present -or $interface.Value -eq 0){throw 'This mode needs the existing prepared UCSI interface. It will not enable the interface automatically; inspect the saved preparation state before proceeding.'}
if($swapRequestedMode -eq 'InspectModes'){
    $run=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-ASUS-modes-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $run|Out-Null
    $result=Invoke-PartnerSwapModeInspection $run
    Write-Output ('Mode-query result: '+$result.Result+'; private results: '+$run)
    if($result.Result -ne 'Recorded'){exit 1}
    exit 0
}
Test-DeepNativeInterface
if((New-Object IO.DriveInfo([IO.Path]::GetPathRoot($repo))).AvailableFreeSpace -lt 3GB){throw 'Keep at least 3 GiB free for the bounded trace and temporary kernel-view work.'}
if($swapRequestedMode -eq 'TestModeExit'){
    $run=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-ASUS-mode-exit-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $run|Out-Null
    $result=Invoke-PartnerSwapModeExitTest $run
    Write-Output ('Mode-exit result: '+$result.Result+'; router present: '+$result.NewRouter+'; new displays: '+$result.NewDisplays.Count+'; private results: '+$run)
    if($result.Result -ne 'Observed' -or $result.EvidenceErrors.Count){exit 1}
    exit 0
}
$run=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-deep-negotiation-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run|Out-Null
$result=Invoke-PartnerSwapRecording $run $swapRequestedScenario
if($result.Result -ne 'Recorded'){exit 1}
Write-Output 'Windows trace, driver recorder output and raw firmware-query replies saved. Recording success is not GPU success; the evidence now needs decoding.'
Write-Output 'The UCSI test interface stays in its prepared state until you run -Mode UndoUcsi after examination.'
exit 0
