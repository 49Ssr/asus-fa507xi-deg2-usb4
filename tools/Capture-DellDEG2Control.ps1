#requires -Version 5.1
<# Portable successful-connection control. Run on the Intel Dell, not the ASUS.
   Imports exercised capture primitives without running the ASUS workflow. #>
[CmdletBinding()]
param([ValidateSet('Preview','Run','UndoUcsi')][string]$Mode='Preview')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:DellRequestedMode=$Mode
. (Join-Path $PSScriptRoot 'Capture-USB4PartnerSwap.ps1')
$script:BundleRoot=$PSScriptRoot
$script:repo=$script:BundleRoot
$script:privateRoot=Join-Path $script:BundleRoot 'Results'
$script:toolRoot=Join-Path $script:BundleRoot 'tooling'
$script:liveKd=Join-Path $script:toolRoot 'Livekd64.exe'
$script:UcsiTool=Join-Path $script:toolRoot 'UcsiControl.exe'
$script:DeepKd=Join-Path $script:toolRoot 'debugger\kd.exe'
$script:DriverSymbols=Join-Path $script:BundleRoot 'Symbols'
$script:UcsiInstance=$null
$script:UcsiKey=$null
$script:UcsiState=$null

function Assert-DellBundle([switch]$SourcesOnly) {
    $null=Assert-LocalPath $script:BundleRoot
    $manifest=Get-Content -LiteralPath (Join-Path $script:BundleRoot 'bundle-manifest.json') -Raw|ConvertFrom-Json
    if($manifest.Schema -ne 1 -or $manifest.Kind -ne 'DellDEG2Control'){throw 'Unexpected bundle manifest.'}
    foreach($entry in $manifest.Files){
        if($SourcesOnly -and [IO.Path]::GetExtension($entry.Path) -ne '.ps1'){continue}
        if($entry.Path -match '(^|[\\/])\.\.([\\/]|$)' -or [IO.Path]::IsPathRooted($entry.Path)){throw 'Invalid bundle member path.'}
        $path=[IO.Path]::GetFullPath((Join-Path $script:BundleRoot $entry.Path))
        if(-not $path.StartsWith($script:BundleRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Bundle member escaped its directory.'}
        if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $entry.SHA256){throw ('Bundle file is missing or changed: '+$entry.Path)}
    }
    if(-not $SourcesOnly){Assert-DeepTools}
}
function Test-DellResultStorage([string]$Run) {
    # Exercise both creation and replacement before changing the diagnostic DWORD.
    $path=Join-Path $Run ('storage-check-'+[guid]::NewGuid().ToString('N')+'.json')
    try{
        Write-PartnerSwapJson $path ([ordered]@{Step=1})
        Write-PartnerSwapJson $path ([ordered]@{Step=2})
        if((Get-Content -LiteralPath $path -Raw|ConvertFrom-Json).Step -ne 2){throw 'Replacement readback failed.'}
    }catch{throw ('Result storage cannot safely create/replace its state files. Copy the complete bundle onto the Dell SSD and retry. Details: '+$_.Exception.Message)}
    finally{if([IO.File]::Exists($path)){[IO.File]::Delete($path)}}
}
function Write-DellFinalEvidence([string]$Path,[object]$Value,[object]$Status) {
    # Evidence I/O must not prevent original-state restoration in the caller.
    try{Write-PartnerSwapJson $Path $Value}catch{
        $message=[IO.Path]::GetFileName($Path)+': '+$_.Exception.Message
        $Status.EvidenceErrors+=@($message)
        $Status.Result='NotCompleted'
        Write-Warning ('Could not save final evidence; cleanup will still be attempted. '+$message)
    }
}
function Get-DellContext([switch]$ForUndo) {
    if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit Windows PowerShell.'}
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Right-click START.cmd and choose Run as administrator.'}
    $bios=Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS'
    if([string]$bios.SystemManufacturer -notmatch '^Dell\b'){throw 'This entry point is restricted to the Dell control. The ASUS workflow was not started.'}
    $machineId=[string](Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid
    if([string]::IsNullOrWhiteSpace($machineId)){throw 'Machine identity is unavailable.'}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$machineHash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($machineId)))).Replace('-','')}finally{$sha.Dispose()}
    $context=[pscustomobject]@{Manufacturer=[string]$bios.SystemManufacturer;Model=[string]$bios.SystemProductName;MachineHash=$machineHash;UcsiDevice=$null;Hosts=@()}
    if($ForUndo){return $context}
    $devices=@(Get-PnpDevice -PresentOnly -ErrorAction Stop)
    $hosts=@($devices|Where-Object {$_.InstanceId -match '^PCI\\VEN_8086' -and $_.FriendlyName -match 'USB4.*Host Router'})
    if($hosts.Count -lt 1 -or @($hosts|Where-Object {$_.Status -ne 'OK'}).Count){throw 'Expected a healthy Intel USB4 host router on this Dell; preserve the observed state.'}
    $ucsi=@($devices|Where-Object {$_.InstanceId -match '^ACPI\\USBC000\\'})
    if($ucsi.Count -gt 1){throw 'Multiple ACPI UCSI devices found; stop rather than selecting an arbitrary firmware interface.'}
    if($ucsi.Count -eq 1){
        if($ucsi[0].Status -ne 'OK'){throw 'The Dell UCSI device is not healthy; no diagnostic setting was changed.'}
        $service=[string](Get-PnpDeviceProperty -InstanceId $ucsi[0].InstanceId -KeyName DEVPKEY_Device_Service -ErrorAction Stop).Data
        if($service -ine 'UcmUcsiAcpiClient'){throw 'The UCSI device is not using the expected Microsoft ACPI client.'}
        $context.UcsiDevice=$ucsi[0].InstanceId
    }
    $context.Hosts=$hosts
    return $context
}
function Set-DellTarget([object]$Context,[string]$Instance) {
    if($Instance -notmatch '^ACPI\\USBC000\\[^\\]+$'){throw 'Unexpected UCSI instance syntax.'}
    $script:UcsiInstance=$Instance
    $script:UcsiKey='HKLM:\SYSTEM\CurrentControlSet\Enum\'+$Instance+'\Device Parameters'
    $script:UcsiState=Join-Path $script:privateRoot ('State\'+$Context.MachineHash+'.json')
}
function Assert-DellDisconnected([switch]$Ask) {
    for($attempt=0;$attempt -lt 3;$attempt++){
        if($Ask){$null=Read-Host 'Disconnect DEG2 USB-C from the Dell; keep dock power on. Press Enter when disconnected'}
        $dock=@(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786|^USB\\VID_8087&PID_5787|^USB\\VID_041F&PID_D002'})
        if($dock.Count -eq 0){return}
        if(-not $Ask){break}
        Write-Warning 'DEG2 is still enumerated. Wait for its removal before continuing.'
    }
    throw 'DEG2 has not disappeared; targeted UCSI preparation/cleanup was not attempted.'
}
function Get-DellInterfaceReadiness([string]$Directory) {
    if(-not(Test-Path -LiteralPath $Directory)){New-Item -ItemType Directory -Path $Directory|Out-Null}
    $code=Invoke-ProbeProcess $script:UcsiTool @('/?') $Directory 5
    $output=[IO.File]::ReadAllText((Join-Path $Directory 'launcher-stdout.txt'))+[IO.File]::ReadAllText((Join-Path $Directory 'launcher-stderr.txt'))
    # The shipped CLI returns 1 for /? even when enumeration and help succeed.
    if($code -notin @(0,1) -or $output -match 'No UCSI device found|Failed to get UCSI device info' -or $output -notmatch 'UcsiControl\.exe.*Send|Usage:'){return $false}
    $nativeDevices=@([regex]::Matches($output,'(?m)^#\d+\*?\s+(ACPI\\[^\r\n]+)'))
    if($nativeDevices.Count -ne 1 -or $nativeDevices[0].Groups[1].Value.Trim() -ine $script:UcsiInstance){throw 'Native enumeration did not identify exactly the selected Dell UCSI interface.'}
    return $true
}
function Initialize-DellUcsi([object]$Context,[string]$Run) {
    if($null -eq $Context.UcsiDevice){
        Write-Warning 'No Microsoft ACPI UCSI device is present. USB4/USB traces and recorders will still be captured; firmware-query coverage will be marked unavailable.'
        return [pscustomobject]@{Available=$false;Reason='No ACPI USBC000 device';Prepared=$false}
    }
    Set-DellTarget $Context $Context.UcsiDevice
    $stateDir=Split-Path $script:UcsiState
    if(-not(Test-Path -LiteralPath $stateDir)){New-Item -ItemType Directory -Path $stateDir|Out-Null}
    $current=Get-DeepInterfaceState
    $saved=$null
    if(Test-Path -LiteralPath $script:UcsiState){
        $saved=Get-Content -LiteralPath $script:UcsiState -Raw|ConvertFrom-Json
        if($saved.MachineHash -cne $Context.MachineHash -or $saved.Instance -cne $script:UcsiInstance -or $saved.Key -cne $script:UcsiKey){throw 'The existing Dell original-state record belongs to another target.'}
        if($saved.Stage -eq 'Restored'){
            if(-not(Test-DeepInterfaceEqual $current $saved.Original)){throw 'Registry state changed since the previous restoration; preserve it for review.'}
            [IO.File]::Copy($script:UcsiState,($script:UcsiState+'.restored-'+[guid]::NewGuid().ToString('N')+'.json'),$false)
            $saved=$null
        }elseif($saved.Stage -notin @('OriginalSaved','EnabledRestartPending','AwaitingWindowsRestart','Ready')){throw 'Finish UNDO.cmd for the previous preparation before making another.'}
    }
    if($null -eq $saved){
        foreach($name in @('UcmUcsiCx.sys','UcmUcsiAcpiClient.sys')){
            $driver=Join-Path $env:SystemRoot ('System32\drivers\'+$name)
            $null=Assert-MicrosoftExecutable $driver $name
        }
        $network=Get-DeepNetworkState
        $saved=[pscustomobject]@{Schema=1;MachineHash=$Context.MachineHash;Instance=$script:UcsiInstance;Key=$script:UcsiKey;Original=$current;Modified=(-not $current.Present -or $current.Value -eq 0);ExpectedValue=$(if($current.Present -and $current.Value -ne 0){$current.Value}else{1});NetworkBefore=$network;CreatedUtc=[DateTime]::UtcNow.ToString('o');Stage='OriginalSaved'}
        Write-PartnerSwapJson $script:UcsiState $saved
    }else{
        if(-not $current.Present -or $current.Value -ne $saved.ExpectedValue){throw 'Current UCSI setting differs from the saved preparation; use UNDO.cmd for review.'}
    }
    $check=Join-Path $Run 'UcsiInterfaceCheck'
    if($saved.Stage -eq 'OriginalSaved' -and $saved.Modified){
        New-ItemProperty -LiteralPath $script:UcsiKey -Name TestInterfaceEnabled -PropertyType DWord -Value 1 -Force|Out-Null
        $saved.Stage='EnabledRestartPending';Write-PartnerSwapJson $script:UcsiState $saved
    }
    if($saved.Stage -ne 'OriginalSaved' -and (Get-DellInterfaceReadiness $check)){
        $saved.Stage='Ready';Write-PartnerSwapJson $script:UcsiState $saved
        return [pscustomobject]@{Available=$true;Reason=$null;Prepared=$true}
    }
    if($saved.Stage -eq 'OriginalSaved' -and -not $saved.Modified -and (Get-DellInterfaceReadiness $check)){
        $saved.Stage='Ready';Write-PartnerSwapJson $script:UcsiState $saved
        return [pscustomobject]@{Available=$true;Reason=$null;Prepared=$true}
    }
    try{Restart-DeepUcsi}catch{
        if($_.Exception.Message -match 'normal Windows Restart'){$saved.Stage='AwaitingWindowsRestart';Write-PartnerSwapJson $script:UcsiState $saved}
        throw
    }
    $readback=Get-DeepInterfaceState
    if(-not $readback.Present -or $readback.Value -ne $saved.ExpectedValue){throw 'Dell test-interface readback failed.'}
    for($attempt=0;$attempt -lt 3;$attempt++){
        if(Get-DellInterfaceReadiness $check){$saved.Stage='Ready';Write-PartnerSwapJson $script:UcsiState $saved;return [pscustomobject]@{Available=$true;Reason=$null;Prepared=$true}}
        Start-Sleep -Milliseconds 500
    }
    throw 'Dell UCSI interface did not become usable. Original state is saved; cleanup or UNDO.cmd restores it.'
}
function Restore-DellUcsi([object]$Context) {
    $statePath=Join-Path $script:privateRoot ('State\'+$Context.MachineHash+'.json')
    if(-not(Test-Path -LiteralPath $statePath)){Write-Host 'No diagnostic setting was saved for this Dell.';return}
    $saved=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
    Set-DellTarget $Context $saved.Instance
    if($saved.MachineHash -cne $Context.MachineHash -or $saved.Key -cne $script:UcsiKey){throw 'Original-state target mismatch.'}
    if($saved.Stage -eq 'Restored'){Write-Host 'Original Dell UCSI setting is already restored.';return}
    $current=Get-DeepInterfaceState
    if(-not(Test-DeepInterfaceEqual $current $saved.Original)){
        if(-not $current.Present -or $current.Value -ne $saved.ExpectedValue){throw 'Unexpected intervening UCSI registry value; it was preserved.'}
        if($saved.Original.Present){New-ItemProperty -LiteralPath $script:UcsiKey -Name TestInterfaceEnabled -PropertyType DWord -Value $saved.Original.Value -Force|Out-Null}
        else{Remove-ItemProperty -LiteralPath $script:UcsiKey -Name TestInterfaceEnabled -ErrorAction Stop}
    }
    if(-not(Test-DeepInterfaceEqual (Get-DeepInterfaceState) $saved.Original)){throw 'Original-value verification failed.'}
    if($saved.Modified){
        $saved.Stage='RegistryRestoredRestartPending'
        try{Write-PartnerSwapJson $script:UcsiState $saved}finally{Restart-DeepUcsi}
    }
    $saved.Stage='Restored';Write-PartnerSwapJson $script:UcsiState $saved
    Write-Host 'Original Dell diagnostic setting restored.' -ForegroundColor Green
}
function Save-DellInventory([string]$Directory,[string]$Phase) {
    $devices=@(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {
        $_.Class -eq 'Display' -or $_.InstanceId -match '^USB4\\|^PCI\\VEN_(8086|10DE)|^USB\\VID_(8087|041F|0BDA)|^ACPI\\USBC000\\'
    }|ForEach-Object {
        $device=$_;$properties=@{};$errorText=$null
        try{
            $readErrors=@()
            foreach($p in @(Get-PnpDeviceProperty -InstanceId $device.InstanceId -KeyName @('DEVPKEY_Device_Parent','DEVPKEY_Device_Service','DEVPKEY_Device_DriverVersion','DEVPKEY_Device_ProblemCode','DEVPKEY_Device_LocationPaths') -ErrorAction SilentlyContinue -ErrorVariable +readErrors)){$properties[$p.KeyName]=$p.Data}
            if($readErrors.Count){$errorText=($readErrors|ForEach-Object {$_.Exception.Message}|Select-Object -Unique)-join '; '}
        }catch{$errorText=$_.Exception.Message}
        [pscustomobject]@{Status=$device.Status;Class=$device.Class;FriendlyName=$device.FriendlyName;InstanceId=$device.InstanceId;Properties=$properties;PropertyError=$errorText}
    })
    $result=[pscustomobject]@{Utc=[DateTime]::UtcNow.ToString('o');Devices=$devices;Error=$null}
    Write-PartnerSwapJson (Join-Path $Directory ('devices-'+$Phase+'.json')) $result
    return $result
}
function Save-DellDriverInputs([string]$Run) {
    $directory=Join-Path $Run 'DriverImages';New-Item -ItemType Directory -Path $directory|Out-Null
    $names=@('ntoskrnl.exe','ACPI.sys','Wdf01000.sys','WppRecorder.sys','Usb4HostRouter.sys','Usb4DeviceRouter.sys','UcmCx.sys','UcmUcsiCx.sys','UcmUcsiAcpiClient.sys','USBXHCI.sys','UCX01000.sys','USBHUB3.sys','SpbCx.sys','pci.sys')
    $rows=foreach($name in $names){
        $path=Join-Path $env:SystemRoot ('System32\drivers\'+$name)
        if($name -eq 'ntoskrnl.exe'){$path=Join-Path $env:SystemRoot ('System32\'+$name)}
        $service=[IO.Path]::GetFileNameWithoutExtension($name)
        $key='HKLM:\SYSTEM\CurrentControlSet\Services\'+$service
        if(Test-Path -LiteralPath $key){$p=Get-ItemProperty -LiteralPath $key;if($p.PSObject.Properties.Name -contains 'ImagePath'){$candidate=[Environment]::ExpandEnvironmentVariables([string]$p.ImagePath).Trim('"');if($candidate.StartsWith('\SystemRoot\')){$candidate=Join-Path $env:SystemRoot $candidate.Substring(12)}elseif($candidate.StartsWith('\??\')){$candidate=$candidate.Substring(4)}elseif(-not [IO.Path]::IsPathRooted($candidate)){$candidate=Join-Path $env:SystemRoot $candidate};if(Test-Path -LiteralPath $candidate -PathType Leaf){$path=$candidate}}}
        $row=[ordered]@{Name=$name;Path=$path;Present=$false;Version=$null;SHA256=$null;Pdb=$null;Error=$null}
        if(Test-Path -LiteralPath $path -PathType Leaf){try{$row.Present=$true;$copy=Join-Path $directory $name;Copy-Item -LiteralPath $path -Destination $copy -ErrorAction Stop;$row.Version=[Diagnostics.FileVersionInfo]::GetVersionInfo($copy).FileVersion;$row.SHA256=(Get-FileHash -LiteralPath $copy).Hash;$row.Pdb=Get-ImagePdbInfo $copy}catch{$row.Error=$_.Exception.Message}}
        $row
    }
    Write-PartnerSwapJson (Join-Path $Run 'driver-inputs.private.json') @($rows)
    $os=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    Write-PartnerSwapJson (Join-Path $Run 'system.private.json') ([ordered]@{Utc=[DateTime]::UtcNow.ToString('o');Build=[string]$os.CurrentBuildNumber;UBR=$os.UBR;DisplayVersion=$os.DisplayVersion;BIOS=@(Get-CimInstance Win32_BIOS|Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate);PowerShell=[string]$PSVersionTable.PSVersion})
}
function Invoke-DellRecorders([string]$Directory,[string]$DriverImages,[switch]$Warmup) {
    New-Item -ItemType Directory -Path $Directory|Out-Null
    $result=[ordered]@{StartedUtc=[DateTime]::UtcNow.ToString('o');ExitCode=$null;TranscriptCompleted=$false;Error=$null;ExactSymbolsRequired=$true;HelperUnloadingVerified=$false}
    try{
        $cache=Join-Path $script:privateRoot 'SymbolCache'
        if(-not(Test-Path -LiteralPath $cache)){New-Item -ItemType Directory -Path $cache|Out-Null}
        $symbolRoot='srv*'+$cache+'*https://msdl.microsoft.com/download/symbols'
        $commands=@('.symopt+0x400',('.exepath '+$DriverImages+';'+$env:SystemRoot+'\System32;'+$env:SystemRoot+'\System32\drivers'),'.echo DELL_RECORDER_BEGIN')
        if($Warmup){$commands+=@('.reload /f nt','.reload /f Wdf01000.sys','.reload /f WppRecorder.sys','.reload /f Usb4HostRouter.sys','.reload /f Usb4DeviceRouter.sys','.reload /f UcmUcsiCx.sys','.reload /f UcmUcsiAcpiClient.sys','.reload /f UcmCx.sys')}
        else{$commands+=@(New-DeepRecorderCommands|Where-Object {$_ -ne 'q' -and $_ -notlike '.exepath*'})}
        $commands+=@('lmv m Usb4HostRouter','lmv m Usb4DeviceRouter','lmv m UcmUcsiCx','.echo DELL_RECORDER_END','q')
        $scriptPath=Join-Path $Directory 'recorders.wds';[IO.File]::WriteAllLines($scriptPath,$commands,[Text.Encoding]::ASCII)
        $result.ExitCode=Invoke-ProbeProcess $script:liveKd @('-accepteula','-b','-k',$script:DeepKd,'-noshell','-ses','-cf',$scriptPath) $Directory 90
        $output=[IO.File]::ReadAllText((Join-Path $Directory 'debugger.txt'))
        $result.TranscriptCompleted=($output.Contains('DELL_RECORDER_BEGIN') -and $output.Contains('DELL_RECORDER_END'))
        if(-not $result.TranscriptCompleted){$result.Error='Both recorder markers were not reached.'}
    }catch{$result.Error=$_.Exception.Message}
    $result.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    Write-PartnerSwapJson (Join-Path $Directory 'status.json') $result
    return $result
}
function Invoke-DellFirmwareQueries([string]$Directory) {
    return Invoke-Usb4FirmwareQueries $Directory
}
function Get-DellMilestones([object]$Before,[object]$After) {
    $ids=@($Before.Devices|ForEach-Object InstanceId)
    $newDisplays=@($After.Devices|Where-Object {$_.Class -eq 'Display' -and $ids -notcontains $_.InstanceId})
    return [ordered]@{Deg2RouterPresent=(@($After.Devices|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'}).Count -gt 0);NewDisplayAdapters=$newDisplays;NewNvidiaPresent=(@($newDisplays|Where-Object {$_.InstanceId -match '^PCI\\VEN_10DE'}).Count -gt 0);NvidiaDriverBound=(@($newDisplays|Where-Object {$_.Properties['DEVPKEY_Device_Service'] -eq 'nvlddmkm' -and $_.Status -eq 'OK'}).Count -gt 0)}
}
function Invoke-DellRun([object]$Context,[string]$Run) {
    $status=[ordered]@{Schema=1;Kind='DellDEG2Control';StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotCompleted';Error=$null;EvidenceErrors=@();Markers=@();Firmware=$null;Warmup=$null;Recorders=$null;Milestones=$null;OwnerDisplayImage=$null;Cleanup=$null;WirePacketsCaptured=$false;CoverageRequiresAnalysis=$true}
    $trace=$null;$greenShown=$false;$awaitRestart=$false
    try{
        Assert-DellDisconnected -Ask
        Write-PartnerSwapJson (Join-Path $Run 'network-before.private.json') (Get-DeepNetworkState)
        Save-DellDriverInputs $Run
        $firmware=Initialize-DellUcsi $Context $Run
        $status.Firmware=$firmware
        Write-Host 'Preparing matching Microsoft symbols before attachment. Keep DEG2 disconnected.' -ForegroundColor Cyan
        $status.Warmup=Invoke-DellRecorders (Join-Path $Run 'SymbolWarmup') (Join-Path $Run 'DriverImages') -Warmup
        $before=Save-DellInventory $Run 'before'
        $trace=Start-ConnectionTrace $Run
        Start-Sleep -Seconds 5
        $status.Markers+=@{Name='AttachPrompt';Utc=[DateTime]::UtcNow.ToString('o')}
        Write-Host 'GREEN: connect the powered DEG2 upstream cable to the SAME Dell Thunderbolt port that previously worked. Leave the GPU display cable connected.' -ForegroundColor Green
        $greenShown=$true
        Start-Sleep -Seconds 25
        $status.Markers+=@{Name='PassiveWindowEnd';Utc=[DateTime]::UtcNow.ToString('o')}
        $passive=Save-DellInventory $Run 'passive'
        $status.Milestones=Get-DellMilestones $before $passive
        $status.Recorders=Invoke-DellRecorders (Join-Path $Run 'IFR') (Join-Path $Run 'DriverImages')
        if($firmware.Available){$status.Firmware=Invoke-DellFirmwareQueries (Join-Path $Run 'UCSI')}
        $after=Save-DellInventory $Run 'after-queries'
        $status.MilestonesAfterQueries=Get-DellMilestones $before $after
        $status.Result='Recorded'
    }catch{
        $status.Error=$_.Exception.Message
        $awaitRestart=($status.Error -match 'normal Windows Restart')
        Write-Warning $status.Error
    }finally{
        if($null -ne $trace){
            try{Stop-ConnectionTrace $trace $Run;if(-not $trace.Stopped){throw 'Owned ETW session did not stop normally.'}}catch{$status.Result='NotCompleted';$status.Error=$_.Exception.Message}
            Write-DellFinalEvidence (Join-Path $Run 'trace-status.json') $trace $status
        }
        $etl=Join-Path $Run 'connection.etl'
        try{$status.EtlBytes=if(Test-Path -LiteralPath $etl -PathType Leaf){(Get-Item -LiteralPath $etl).Length}else{0}}catch{$status.EtlBytes=0;$status.EvidenceErrors+=@('ETL metadata: '+$_.Exception.Message);$status.Result='NotCompleted'}
        $status.FileCapRisk=($status.EtlBytes -ge 1000MB)
        if($status.Result -eq 'Recorded' -and $status.EtlBytes -eq 0){$status.Result='NotCompleted';$status.Error='ETL is absent or empty.'}
        if($greenShown){try{$answer=Read-Host 'Recording stopped. Did the GPU HDMI/DP display show an image? Type Y, N, or Unknown';$status.OwnerDisplayImage=if($answer -match '^(?i:y|yes)$'){$true}elseif($answer -match '^(?i:n|no)$'){$false}else{$null}}catch{$status.OwnerObservationError=$_.Exception.Message}}
        try{Write-PartnerSwapJson (Join-Path $Run 'network-after.private.json') (Get-DeepNetworkState)}catch{$status.NetworkAfterError=$_.Exception.Message}
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-DellFinalEvidence (Join-Path $Run 'status.json') $status $status
        if($awaitRestart){$status.Cleanup='AwaitingWindowsRestart';Write-Warning 'Restart Windows normally, then run START.cmd again. No automatic restart was issued. Keep this USB state backup.'}
        else{
            try{
                if($greenShown){Assert-DellDisconnected -Ask}else{Assert-DellDisconnected}
                Restore-DellUcsi $Context
                $status.Cleanup='OriginalSettingRestoredOrNoChange'
            }catch{$status.Cleanup=$_.Exception.Message;Write-Warning ('Cleanup needs UNDO.cmd on this Dell: '+$status.Cleanup)}
        }
        try{Write-PartnerSwapJson (Join-Path $Run 'network-after-cleanup.private.json') (Get-DeepNetworkState)}catch{$status.NetworkCleanupSnapshotError=$_.Exception.Message}
        $status.CleanupFinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-DellFinalEvidence (Join-Path $Run 'status.json') $status $status
        Write-Host ('Results directory: '+$Run) -ForegroundColor Cyan
        Write-Host ('Capture result: '+$status.Result+'; cleanup: '+$status.Cleanup)
    }
    return $status
}

# The bounded PE/PDB identity reader below is shared with the earlier audited probe.
# It reads driver files only and never loads, installs or modifies them.
function Get-ImagePdbInfo([string]$Path) {
    $data=[IO.File]::ReadAllBytes($Path)
    function U16([int]$Offset) {
        if($Offset -lt 0 -or $Offset -gt $data.Length-2){throw 'Truncated PE image.'}
        [BitConverter]::ToUInt16($data,$Offset)
    }
    function U32([int]$Offset) {
        if($Offset -lt 0 -or $Offset -gt $data.Length-4){throw 'Truncated PE image.'}
        [BitConverter]::ToUInt32($data,$Offset)
    }
    if($data.Length -lt 64 -or (U16 0) -ne 0x5a4d){throw 'Invalid DOS header.'}
    $pe=[int](U32 60)
    if($pe -lt 64 -or $pe -gt $data.Length-264 -or (U32 $pe) -ne 0x4550){throw 'Invalid PE header.'}
    $sections=[int](U16 ($pe+6)); $optional=$pe+24; $optionalBytes=[int](U16 ($pe+20))
    if((U16 ($pe+4)) -ne 0x8664 -or (U16 $optional) -ne 0x20b -or $optionalBytes -lt 168 -or $sections -lt 1 -or $sections -gt 96){throw 'Expected bounded x64 PE image.'}
    $debugRva=U32 ($optional+160); $debugBytes=U32 ($optional+164)
    if($debugBytes -lt 28 -or $debugBytes -gt 65536 -or $debugBytes%28 -ne 0){throw 'Invalid PE debug directory.'}
    $table=$optional+$optionalBytes; $debugOffset=$null
    for($i=0;$i -lt $sections;$i++) {
        $entry=$table+$i*40; $rva=U32 ($entry+12); $rawBytes=U32 ($entry+16); $rawOffset=U32 ($entry+20)
        if([uint64]$debugRva -ge [uint64]$rva -and [uint64]$debugRva+[uint64]$debugBytes -le [uint64]$rva+[uint64]$rawBytes) {
            if($null -ne $debugOffset){throw 'Overlapping PE debug mappings.'}
            $debugOffset=[int64]$rawOffset+[int64]$debugRva-[int64]$rva
        }
    }
    if($null -eq $debugOffset -or $debugOffset -gt $data.Length-$debugBytes){throw 'Unmapped PE debug directory.'}
    $records=@(for($i=0;$i -lt $debugBytes;$i+=28){
        $entry=[int]$debugOffset+$i
        if((U32 ($entry+12)) -ne 2){continue}
        $length=[int64](U32 ($entry+16)); $raw=[int64](U32 ($entry+24))
        if($length -lt 25 -or $raw -lt 0 -or $length -gt 4096 -or $raw -gt $data.Length-$length){throw 'Invalid CodeView record.'}
        if([Text.Encoding]::ASCII.GetString($data,[int]$raw,4) -ne 'RSDS'){continue}
        $guidBytes=New-Object byte[] 16; [Array]::Copy($data,$raw+4,$guidBytes,0,16)
        $guid=New-Object Guid (,$guidBytes); $age=U32 ([int]$raw+20)
        $nameText=[Text.Encoding]::ASCII.GetString($data,[int]$raw+24,[int]$length-24)
        $nul=$nameText.IndexOf([char]0); if($nul -lt 0){throw 'Unterminated PDB name.'}
        $name=[IO.Path]::GetFileName($nameText.Substring(0,$nul))
        if($name -notmatch '^[a-zA-Z0-9_.-]+\.pdb$' -or $age -eq 0){throw 'Invalid PDB identity.'}
        [pscustomobject]@{Name=$name;Key=$guid.ToString('N').ToUpperInvariant()+$age.ToString('X');Image=$Path}
    })
    if($records.Count -ne 1){throw 'Expected exactly one RSDS record.'}
    return $records[0]
}

if($MyInvocation.InvocationName -eq '.'){return}
if($script:DellRequestedMode -eq 'Preview'){
    Write-Output 'Dell Intel USB4 control. START.cmd runs the guided recording from this drive.'
    Write-Output 'The capture starts before DEG2 insertion, saves driver files/PDB identities, reads flight recorders, and sends only firmware GET requests after passive observation.'
    Write-Output 'One documented UCSI diagnostic value is saved/enabled if supported. After recording, disconnect DEG2 when prompted so the original value can be restored.'
    Write-Output 'No firmware flash, driver-package replacement, network edit, boot-security change or automatic Windows restart is requested.'
    exit 0
}
Assert-DellBundle -SourcesOnly:($script:DellRequestedMode -eq 'UndoUcsi')
$context=Get-DellContext -ForUndo:($script:DellRequestedMode -eq 'UndoUcsi')
if($script:DellRequestedMode -eq 'UndoUcsi'){Assert-DellDisconnected -Ask;Restore-DellUcsi $context;exit 0}
if((New-Object IO.DriveInfo([IO.Path]::GetPathRoot($script:BundleRoot))).AvailableFreeSpace -lt 3GB){throw 'Keep at least 3 GiB free on the USB drive for trace/symbol results.'}
$run=Join-Path $script:privateRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-Dell-DEG2-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run -Force|Out-Null
Test-DellResultStorage $run
Write-PartnerSwapJson (Join-Path $run 'host.private.json') $context
$result=Invoke-DellRun $context $run
if($result.Cleanup -eq 'AwaitingWindowsRestart'){exit 3010}
if($result.Result -ne 'Recorded'){exit 1}
if($result.Cleanup -ne 'OriginalSettingRestoredOrNoChange'){exit 2}
exit 0
