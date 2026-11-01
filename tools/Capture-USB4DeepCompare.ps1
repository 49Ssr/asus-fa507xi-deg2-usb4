#requires -Version 5.1
<# Passive Dell/ASUS comparison. Native Task Manager dump is owner-generated.
   No UcsiControl, LiveKD, firmware command, device restart or setting change. #>
[CmdletBinding()]
param([ValidateSet('Preview','Capture','FinishDump','Return','StopTrace')][string]$Mode='Preview',
      [ValidateSet('Dell','Asus')][string]$Target='Dell', [string]$TransportDirectory='', [string]$RunDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$deepMode=$Mode;$deepTarget=$Target
. (Join-Path $PSScriptRoot 'Usb4Capture.Common.ps1')
$script:DeepWorkRoot=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'USB4-Deep-Compare'

function Write-DeepJson([string]$Path,[object]$Value) {
    $full=[IO.Path]::GetFullPath($Path);$temp=$full+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try{
        $data=(New-Object Text.UTF8Encoding($false)).GetBytes(($Value|ConvertTo-Json -Depth 18))
        $stream=New-Object IO.FileStream($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try{$stream.Write($data,0,$data.Length);$stream.Flush($true)}finally{$stream.Dispose()}
        if([IO.File]::Exists($full)){[IO.File]::Replace($temp,$full,[NullString]::Value)}else{[IO.File]::Move($temp,$full)}
    }finally{if([IO.File]::Exists($temp)){[IO.File]::Delete($temp)}}
}
function Initialize-DeepNative {
    if(-not ('Usb4DeepCompare.Native' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'deep-compare\DeepCapture.Native.cs')}
}
function Get-DeepMachineHash {
    $id=[string](Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Cryptography').MachineGuid
    if([string]::IsNullOrWhiteSpace($id)){throw 'Windows machine identity unavailable.'}
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($id))).Replace('-','')}finally{$sha.Dispose()}
}
function Assert-DeepRelative([string]$Name) {
    if([string]::IsNullOrWhiteSpace($Name) -or [IO.Path]::IsPathRooted($Name) -or $Name -match '(^|[\\/])\.\.?([\\/]|$)|[:\r\n]' -or $Name -match '[. ]([\\/]|$)'){throw 'Unsafe relative evidence path.'}
}
function Assert-DeepNoReparse([string]$Path) {
    $item=Get-Item -LiteralPath $Path -Force
    while($null -ne $item){
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Reparse points are not supported for evidence storage.'}
        if($item -is [IO.FileInfo]){$item=$item.Directory}else{$item=$item.Parent}
    }
}
function Get-DeepDrive([string]$Path) {
    $full=Assert-LocalPath $Path;$root=[IO.Path]::GetPathRoot($full)
    if($root -notmatch '^[A-Za-z]:\\$'){throw 'Use a local drive-letter path.'}
    $volume=Get-Volume -DriveLetter $root.Substring(0,1) -ErrorAction Stop
    $disks=@(Get-Partition -DriveLetter $root.Substring(0,1) -ErrorAction Stop|Get-Disk -ErrorAction Stop)
    if($disks.Count -ne 1){throw 'Drive-to-disk association is ambiguous.'}
    return [pscustomobject]@{Root=$root;Free=[long]$volume.SizeRemaining;FileSystem=[string]$volume.FileSystem;Bus=[string]$disks[0].BusType;IsBoot=[bool]$disks[0].IsBoot;IsSystem=[bool]$disks[0].IsSystem}
}
function Assert-DeepHostIdentity([string]$Manufacturer,[string]$Model,[object[]]$Hosts,[string]$Which) {
    if($Which -eq 'Dell'){
        if($Manufacturer -notmatch '^Dell\b' -or $Model -cne 'Latitude 5540'){throw 'This entry point requires the known Dell Latitude 5540.'}
        $expected='^PCI\\VEN_8086'
    }else{
        if($Manufacturer -notmatch '(?i)ASUS|ASUSTeK' -or $Model -notmatch '(?i)(^|[^a-z0-9])FA507XI([^a-z0-9]|$)'){throw 'This entry point requires the known ASUS FA507XI.'}
        $expected='^PCI\\VEN_1022'
    }
    if(-not @($Hosts|Where-Object {$_.InstanceId -match $expected -and $_.FriendlyName -match 'USB4.*Host Router' -and $_.Status -eq 'OK'}).Count){throw 'Expected healthy USB4 host router not found.'}
}
function Get-DeepCaptureContext([string]$Which) {
    if(-not [Environment]::Is64BitProcess -or $PSVersionTable.PSVersion.Major -ne 5){throw 'Use 64-bit Windows PowerShell 5.1.'}
    $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Right-click the matching START launcher and choose Run as administrator.'}
    $bios=Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS'
    $devices=@(Get-PnpDevice -PresentOnly -ErrorAction Stop)
    Assert-DeepHostIdentity ([string]$bios.SystemManufacturer) ([string]$bios.SystemProductName) $devices $Which
    $ucsi=@($devices|Where-Object {$_.InstanceId -match '^ACPI\\USBC000\\'})
    if($ucsi.Count -ne 1 -or $ucsi[0].Status -ne 'OK'){throw 'Exactly one healthy ACPI UCSI device is required for this comparison.'}
    $binding=Get-DeepPnpProperties $ucsi[0].InstanceId @('DEVPKEY_Device_Service')
    $service=[string]$binding.Values['DEVPKEY_Device_Service']
    if($service -ine 'UcmUcsiAcpiClient'){throw 'Unexpected UCSI driver binding.'}
    return [pscustomobject]@{Target=$Which;Manufacturer=[string]$bios.SystemManufacturer;Model=[string]$bios.SystemProductName;MachineHash=(Get-DeepMachineHash);MemoryBytes=[long](Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory;UcsiInstance=$ucsi[0].InstanceId}
}
function Read-DeepBundle([string]$Directory=$PSScriptRoot) {
    $manifest=Get-Content -LiteralPath (Join-Path $Directory 'bundle-manifest.json') -Raw|ConvertFrom-Json
    if($manifest.Schema -ne 1 -or $manifest.Kind -ne 'USB4DeepCompare' -or $manifest.BundleId -notmatch '^[a-f0-9]{32}$'){throw 'Unexpected bundle manifest.'}
    $seen=@{}
    foreach($file in $manifest.Files){
        Assert-DeepRelative $file.Path
        if($seen.ContainsKey($file.Path)){throw 'Duplicate bundle entry.'};$seen[$file.Path]=$true
        $path=Join-Path $Directory $file.Path;Assert-DeepNoReparse $path
        if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $file.SHA256){throw ('Bundle hash mismatch: '+$file.Path)}
    }
    foreach($required in @('Capture-USB4DeepCompare.ps1','Usb4Capture.Common.ps1','deep-compare\DeepCapture.Native.cs','START-DELL.cmd','START-ASUS.cmd','FINISH-DUMP.cmd','RETURN.cmd','STOP-TRACE.cmd','README.txt')){
        if(-not $seen.ContainsKey($required)){throw ('Bundle entry missing: '+$required)}
    }
    return $manifest
}
function Copy-DeepBundle([string]$Source,[string]$Destination) {
    $verified=Read-DeepBundle $Source
    $full=Assert-LocalPath $Destination;$prefix=[IO.Path]::GetFullPath((Join-Path $script:DeepWorkRoot 'Kits'))+'\'
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $full)){throw 'Staging requires a new directory under the owned Kits folder.'}
    $ancestor=[IO.Path]::GetDirectoryName($full)
    while(-not(Test-Path -LiteralPath $ancestor)){$ancestor=[IO.Path]::GetDirectoryName($ancestor)}
    Assert-DeepNoReparse $ancestor
    $null=New-Item -ItemType Directory -Path $full -Force;Assert-DeepNoReparse $full
    foreach($file in $verified.Files){
        $dest=Join-Path $full $file.Path;$null=New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force
        [IO.File]::Copy((Join-Path $Source $file.Path),$dest,$false)
        if((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash -cne $file.SHA256){throw 'SSD staging hash mismatch.'}
    }
    [IO.File]::Copy((Join-Path $Source 'bundle-manifest.json'),(Join-Path $full 'bundle-manifest.json'),$false)
    $null=Read-DeepBundle $full
}
function Get-DeepPnpProperties([string]$InstanceId,[string[]]$Keys) {
    $values=@{};$issues=@();$errors=@();$seen=@{}
    $replies=@(Get-PnpDeviceProperty -InstanceId $InstanceId -KeyName $Keys -ErrorAction SilentlyContinue -ErrorVariable +errors)
    foreach($reply in $replies){
        $keyProperty=$reply.PSObject.Properties['KeyName']
        if($null -eq $keyProperty -or [string]::IsNullOrWhiteSpace([string]$keyProperty.Value)){$issues+=@{Key=$null;Reason='ReplyHasNoKeyName'};continue}
        $key=[string]$keyProperty.Value;$seen[$key]=$true
        if($Keys -notcontains $key){$issues+=@{Key=$key;Reason='UnexpectedReplyKey'};continue}
        # Windows can return a base Win32_PnPDeviceProperty with no Data member.
        # Missing optional metadata must remain unknown, never become zero/false.
        $dataProperty=$reply.PSObject.Properties['Data']
        if($null -eq $dataProperty){$issues+=@{Key=$key;Reason='ReplyHasNoDataMember'};continue}
        try{
            $data=$dataProperty.Value
            if($null -eq $data){$issues+=@{Key=$key;Reason='NullData'};continue}
            $values[$key]=$data
        }catch{$issues+=@{Key=$key;Reason='DataReadFailed';Error=$_.Exception.Message}}
    }
    foreach($key in $Keys){if(-not $seen.ContainsKey($key)){$issues+=@{Key=$key;Reason='NoReplyForRequestedKey'}}}
    foreach($errorRecord in $errors){$issues+=@{Key=$null;Reason='ProviderError';Error=[string]$errorRecord}}
    return [pscustomobject]@{Values=$values;Issues=$issues}
}
function Save-DeepInventory([string]$Directory,[string]$Label) {
    $devices=@(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {$_.Class -in @('Display','Firmware') -or $_.InstanceId -match '^USB4\\|^ACPI\\(USBC000|PS883)|^USB\\VID_(8087|041F|0BDA)|^PCI\\VEN_(8086|1022)'}|ForEach-Object {
        $d=$_
        $properties=Get-DeepPnpProperties $d.InstanceId @('DEVPKEY_Device_Parent','DEVPKEY_Device_Service','DEVPKEY_Device_DriverVersion','DEVPKEY_Device_ProblemCode','DEVPKEY_Device_LocationPaths')
        [pscustomobject]@{Status=$d.Status;Class=$d.Class;FriendlyName=$d.FriendlyName;InstanceId=$d.InstanceId;Properties=$properties.Values;PropertyIssues=$properties.Issues}
    })
    $result=[pscustomobject]@{Utc=[DateTime]::UtcNow.ToString('o');Devices=$devices}
    Write-DeepJson (Join-Path $Directory ('devices-'+$Label+'.private.json')) $result
    return $result
}
function Get-DeepMilestone([object]$Inventory) {
    $router=@($Inventory.Devices|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786'})
    $gpu=@($Inventory.Devices|Where-Object {$_.InstanceId -match '^PCI\\VEN_10DE&DEV_2702' -and $_.Class -eq 'Display'})
    $bound=@($gpu|Where-Object {
        $service=$null
        if($_.Properties -is [Collections.IDictionary]){$service=$_.Properties['DEVPKEY_Device_Service']}
        else{$property=$_.Properties.PSObject.Properties['DEVPKEY_Device_Service'];if($null -ne $property){$service=$property.Value}}
        $_.Status -eq 'OK' -and $service -eq 'nvlddmkm'
    })
    return [pscustomobject]@{RouterPresent=($router.Count -gt 0);RouterHealthy=(@($router|Where-Object Status -eq 'OK').Count -gt 0);BillboardPresent=(@($Inventory.Devices|Where-Object {$_.InstanceId -match '^USB\\VID_041F&PID_D002'}).Count -gt 0);ExternalNvidiaBound=($bound.Count -gt 0)}
}
function Get-DeepNetworkSnapshot {
    $manager=New-Object -ComObject HNetCfg.HNetShare
    return [ordered]@{Utc=[DateTime]::UtcNow.ToString('o');Adapters=@(Get-NetAdapter -IncludeHidden|Select-Object Name,InterfaceDescription,InterfaceGuid,ifIndex,Status);IP=@(Get-NetIPAddress|Select-Object InterfaceIndex,InterfaceAlias,AddressFamily,IPAddress,PrefixLength,PrefixOrigin);Interfaces=@(Get-NetIPInterface|Select-Object InterfaceIndex,InterfaceAlias,AddressFamily,Dhcp,InterfaceMetric);DNS=@(Get-DnsClientServerAddress|Select-Object InterfaceIndex,InterfaceAlias,AddressFamily,ServerAddresses);DefaultRoutes=@(Get-NetRoute|Where-Object {$_.DestinationPrefix -in @('0.0.0.0/0','::/0')}|Select-Object InterfaceIndex,DestinationPrefix,NextHop,RouteMetric);Sharing=@($manager.EnumEveryConnection()|ForEach-Object {$p=$manager.NetConnectionProps($_);$c=$manager.INetSharingConfigurationForINetConnection($_);[pscustomobject]@{Name=$p.Name;Guid=[string]$p.Guid;Shared=[bool]$c.SharingEnabled;Type=$(if($c.SharingEnabled){[int]$c.SharingConnectionType}else{-1})}})}
}
function Get-DeepAcpiHeader([byte[]]$Bytes,[string]$Expected) {
    if($Bytes.Length -lt 36 -or [BitConverter]::ToUInt32($Bytes,4) -ne $Bytes.Length -or [Text.Encoding]::ASCII.GetString($Bytes,0,4) -cne $Expected){throw 'Invalid ACPI table header/length.'}
    $sum=0;foreach($b in $Bytes){$sum=($sum+[int]$b)-band 255}
    if($sum -ne 0){throw 'ACPI table checksum failed.'}
    return [pscustomobject]@{Signature=$Expected;Bytes=$Bytes.Length;Revision=$Bytes[8];ChecksumValid=$true;OemId=[Text.Encoding]::ASCII.GetString($Bytes,10,6);OemTableId=[Text.Encoding]::ASCII.GetString($Bytes,16,8);OemRevision=[BitConverter]::ToUInt32($Bytes,24)}
}
function Save-DeepAcpi([string]$Directory) {
    Initialize-DeepNative
    $null=New-Item -ItemType Directory -Path $Directory
    $ids=@([Usb4DeepCompare.Native]::AcpiIds());$entries=@();$rows=@()
    # DSDT can be reached through FADT rather than the root table enumeration.
    # Request its well-known signature directly if Windows omitted it from the list.
    $dsdtId=[BitConverter]::ToUInt32([Text.Encoding]::ASCII.GetBytes('DSDT'),0)
    $directDsdt=($ids -notcontains $dsdtId)
    $queryIds=@($ids);if($directDsdt){$queryIds+=@($dsdtId)}
    foreach($group in @($queryIds|Group-Object)){
        $id=[uint32]$group.Group[0];$name=[Text.Encoding]::ASCII.GetString([BitConverter]::GetBytes($id))
        $entries+=@{Signature=$name;EnumeratedInstances=$(if($name -eq 'DSDT' -and $directDsdt){0}else{$group.Count});DirectDsdtLookup=($name -eq 'DSDT' -and $directDsdt);Exported=($name -in @('DSDT','SSDT','FACP'))}
        if($name -notin @('DSDT','SSDT','FACP')){continue}
        $data=[Usb4DeepCompare.Native]::AcpiTable($id);$header=Get-DeepAcpiHeader $data $name
        $path=Join-Path $Directory ($name+'.bin');[IO.File]::WriteAllBytes($path,$data)
        $rows+=@{Header=$header;SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;DuplicateInstancesUnavailable=($group.Count -gt 1)}
    }
    if(-not @($rows|Where-Object {$_.Header.Signature -eq 'DSDT'}).Count){throw 'DSDT export unavailable; preserve the error before another capture.'}
    Write-DeepJson (Join-Path $Directory 'acpi-index.private.json') @{Enumerated=$entries;Tables=$rows;OnlyFirstDuplicateAccessible=$true;FirmwareFlashReadback=$false;LicenseTablesExcluded=$true}
}
function Resolve-DeepDriverPath([string]$Name) {
    $allowed=@('ntoskrnl.exe','ACPI.sys','Wdf01000.sys','WppRecorder.sys','Usb4HostRouter.sys','Usb4DeviceRouter.sys','UcmCx.sys','UcmUcsiCx.sys','UcmUcsiAcpiClient.sys','USBXHCI.sys','UCX01000.sys','USBHUB3.sys','SpbCx.sys','pci.sys')
    if($allowed -notcontains $Name){throw 'Unexpected driver input name.'}
    $default=if($Name -eq 'ntoskrnl.exe'){Join-Path $env:SystemRoot ('System32\'+$Name)}else{Join-Path $env:SystemRoot ('System32\drivers\'+$Name)}
    $service=[IO.Path]::GetFileNameWithoutExtension($Name)
    $key='HKLM:\SYSTEM\CurrentControlSet\Services\'+$service
    if(Test-Path -LiteralPath $key){
        $properties=Get-ItemProperty -LiteralPath $key
        if($null -ne $properties.PSObject.Properties['ImagePath']){
            $candidate=[Environment]::ExpandEnvironmentVariables([string]$properties.ImagePath).Trim('"')
            if($candidate.StartsWith('\SystemRoot\',[StringComparison]::OrdinalIgnoreCase)){$candidate=Join-Path $env:SystemRoot $candidate.Substring(12)}
            elseif($candidate.StartsWith('\??\')){$candidate=$candidate.Substring(4)}
            elseif(-not [IO.Path]::IsPathRooted($candidate)){$candidate=Join-Path $env:SystemRoot $candidate}
            $candidate=Assert-LocalPath $candidate
            if([IO.Path]::GetFileName($candidate) -ine $Name){throw ('Unexpected service image name for '+$Name)}
            if(Test-Path -LiteralPath $candidate -PathType Leaf){return $candidate}
        }
    }
    if(Test-Path -LiteralPath $default -PathType Leaf){return $default}
    throw ('Expected driver input missing: '+$Name)
}
function Save-DeepInputs([string]$Directory,[object]$Context) {
    Write-DeepJson (Join-Path $Directory 'context.private.json') $Context
    $os=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    $key='HKLM:\SYSTEM\CurrentControlSet\Enum\'+$Context.UcsiInstance+'\Device Parameters'
    $keyPresent=Test-Path -LiteralPath $key;$item=$null;$present=$false
    if($keyPresent){$item=Get-Item -LiteralPath $key -ErrorAction Stop;$present=@($item.GetValueNames()) -contains 'TestInterfaceEnabled'}
    Write-DeepJson (Join-Path $Directory 'system.private.json') @{Build=[string]$os.CurrentBuildNumber;UBR=$os.UBR;BIOS=@(Get-CimInstance Win32_BIOS|Select-Object Manufacturer,SMBIOSBIOSVersion,ReleaseDate);PowerShell=[string]$PSVersionTable.PSVersion;TestInterface=@{RegistryKeyPresent=$keyPresent;Present=$present;Value=$(if($present){$item.GetValue('TestInterfaceEnabled')}else{$null})};AllCapturedDriversAreInstalledFileCopies=$true;LoadedIdentityRequiresDump=$true}
    $driverRoot=Join-Path $Directory 'DriverImages';$null=New-Item -ItemType Directory -Path $driverRoot
    $rows=foreach($name in @('ntoskrnl.exe','ACPI.sys','Wdf01000.sys','WppRecorder.sys','Usb4HostRouter.sys','Usb4DeviceRouter.sys','UcmCx.sys','UcmUcsiCx.sys','UcmUcsiAcpiClient.sys','USBXHCI.sys','UCX01000.sys','USBHUB3.sys','SpbCx.sys','pci.sys')){
        $source=Resolve-DeepDriverPath $name
        $dest=Join-Path $driverRoot $name;[IO.File]::Copy($source,$dest,$false)
        @{Name=$name;InstalledPath=$source;SHA256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash;Version=[Diagnostics.FileVersionInfo]::GetVersionInfo($dest).FileVersion}
    }
    Write-DeepJson (Join-Path $Directory 'driver-inputs.private.json') @($rows)
    Save-DeepAcpi (Join-Path $Directory 'ACPI')
}
function Read-DeepDumpHeader([string]$Path,[datetime]$NotBefore) {
    $file=Get-Item -LiteralPath $Path -ErrorAction Stop;Assert-DeepNoReparse $file.FullName
    if($file.PSIsContainer -or $file.Extension -ine '.dmp' -or $file.Length -lt 8192 -or $file.LastWriteTimeUtc -lt $NotBefore){throw 'Dump is missing, too small, or older than the recorded endpoint state.'}
    $stream=New-Object IO.FileStream($file.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$header=New-Object byte[] 64;if($stream.Read($header,0,64) -ne 64){throw 'Short dump header.'}}finally{$stream.Dispose()}
    if([Text.Encoding]::ASCII.GetString($header,0,8) -cne 'PAGEDU64' -or [BitConverter]::ToUInt32($header,48) -ne 0x8664 -or [BitConverter]::ToUInt32($header,56) -ne 0x161){throw 'Expected an x64 native full live-kernel dump (PAGE/DU64, LIVE_SYSTEM_DUMP). Kernel stacks/user dumps are not sufficient.'}
    return [pscustomobject]@{Path=$file.FullName;Bytes=$file.Length;LastWriteUtc=$file.LastWriteTimeUtc.ToString('o');HeaderValidated=$true;ContentCoverageRequiresOfflineAnalysis=$true}
}
function Open-DeepTaskManager {
    # This visible native window is the owner-operated snapshot step.
    $taskManager=Assert-MicrosoftExecutable (Join-Path $env:SystemRoot 'System32\Taskmgr.exe') 'Taskmgr.exe'
    Start-Process -FilePath $taskManager -Verb RunAs -WindowStyle Normal | Out-Null
}
function Get-DeepDumpCandidates([string]$Directory,[datetime]$NotBefore) {
    if(-not(Test-Path -LiteralPath $Directory -PathType Container)){return @()}
    $files=@(Get-ChildItem -LiteralPath $Directory -File -Recurse -Filter '*.dmp' -ErrorAction SilentlyContinue|Where-Object {$_.LastWriteTimeUtc -ge $NotBefore}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 256)
    return @($files|ForEach-Object {try{Read-DeepDumpHeader $_.FullName $NotBefore}catch{}})
}
function Resolve-DeepDumpSelection([string]$Selection,[datetime]$NotBefore) {
    $path=$Selection.Trim().Trim('"');$path=Assert-LocalPath $path
    if(Test-Path -LiteralPath $path -PathType Container){
        $candidates=@(Get-DeepDumpCandidates $path $NotBefore)
        if($candidates.Count -ne 1){throw 'That folder must contain exactly one eligible live kernel dump; use Browse to select the file.'}
        return $candidates[0]
    }
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){
        $parent=[IO.Path]::GetDirectoryName($path)
        # Tolerate appending the filename to a path that already names the file.
        if([IO.Path]::GetExtension($parent) -ieq '.dmp' -and (Test-Path -LiteralPath $parent -PathType Leaf)){$path=$parent}
    }
    return Read-DeepDumpHeader $path $NotBefore
}
function Show-DeepDumpPicker([string]$InitialDirectory) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog=New-Object Windows.Forms.OpenFileDialog
    try{
        $dialog.Title='Select the completed FULL live kernel dump';$dialog.Filter='Kernel dump (*.dmp)|*.dmp';$dialog.CheckFileExists=$true;$dialog.Multiselect=$false
        if(Test-Path -LiteralPath $InitialDirectory -PathType Container){$dialog.InitialDirectory=$InitialDirectory}
        if($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){return $dialog.FileName}
        return $null
    }finally{$dialog.Dispose()}
}
function Select-DeepCompletedDump([string]$DefaultDirectory,[datetime]$NotBefore) {
    foreach($attempt in 1..3){
        $answer=Read-Host 'After the FULL dump completes, press Enter to find it automatically; B browses, P leaves the dump pending. A file or folder path also works'
        if($answer -match '^(?i:p|pending)$'){return $null}
        try{
            if([string]::IsNullOrWhiteSpace($answer)){
                $found=@(Get-DeepDumpCandidates $DefaultDirectory $NotBefore)
                if($found.Count -eq 1){Write-Host ('Found completed dump: '+$found[0].Path);return $found[0]}
                $answer=Show-DeepDumpPicker $DefaultDirectory
            }elseif($answer -match '^(?i:b|browse)$'){$answer=Show-DeepDumpPicker $DefaultDirectory}
            if([string]::IsNullOrWhiteSpace($answer)){return $null}
            return Resolve-DeepDumpSelection $answer $NotBefore
        }catch{Write-Warning ('Dump not accepted: '+$_.Exception.Message+' The saved trace is retained; retry or choose P.')}
    }
    return $null
}
function Complete-DeepDumpCapture([object]$Context,[string]$Directory,[object]$Status) {
    if($Status.DumpBaselineQualified -and $null -ne $Status.Dump){Write-Host 'This run already has a qualified snapshot; preserving it.';return}
    $after=Get-Content -LiteralPath (Join-Path $Directory 'devices-after-passive.private.json') -Raw|ConvertFrom-Json
    # The earliest valid snapshot is tied to the observed endpoint state, BEFORE
    # displaying instructions. A later Enter press must not make a valid file stale.
    $notBefore=[datetime]::Parse($after.Utc).ToUniversalTime().AddSeconds(-2)
    $Status.Phase='DumpPending';$Status.Result='TraceCaptured_DumpPending';$Status.Error=$null;$Status.ErrorDetail=$null
    $Status.Markers+=@{Name='FullKernelDumpInstructions';Utc=[DateTime]::UtcNow.ToString('o');EarliestEligibleDumpUtc=$notBefore.ToString('o')}
    Write-DeepJson (Join-Path $Directory 'status.json') $Status
    Write-Host 'Trace is saved. KEEP DEG2 CONNECTED. Task Manager will open for the FULL kernel snapshot.' -ForegroundColor Cyan
    Write-Host 'Details -> System (PID 4) -> Create live kernel memory dump file -> Full live kernel memory dump. Wait for completion, then return here.'
    Open-DeepTaskManager
    $default=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Microsoft\Windows\TaskManager\LiveKernelDumps'
    $dump=Select-DeepCompletedDump $default $notBefore
    if($null -eq $dump){Write-Host 'Dump pending. The trace is retained. FINISH-DUMP.cmd on this laptop resumes this saved run without another connection capture.';return}
    $Status.Dump=$dump;$Status.Phase='AfterDumpInventory'
    $afterDump=Save-DeepInventory $Directory 'after-dump';$end=Get-DeepMilestone $afterDump
    if($Context.Target -eq 'Dell' -and (-not $end.RouterHealthy -or -not $end.ExternalNvidiaBound)){throw 'Dell control changed during snapshot acquisition; dump retained without qualifying the baseline.'}
    if($Context.Target -eq 'Asus' -and ($end.RouterPresent -or -not $end.BillboardPresent)){throw 'ASUS baseline changed during snapshot acquisition; dump retained without qualifying the baseline.'}
    $Status.DumpBaselineQualified=$true;$Status.Markers+=@{Name='DumpAccepted';Utc=[DateTime]::UtcNow.ToString('o')}
    $Status.OwnerOutput=Read-Host 'Did the display connected to the RTX 4080 SUPER show an image? Type Y, N, or Unknown'
    $Status.Result='Captured_RequiresOfflinePolicyAndMemoryValidation';$Status.Phase='Captured'
}
function Assert-DeepRun([string]$Directory) {
    $full=Assert-LocalPath $Directory;$prefix=[IO.Path]::GetFullPath((Join-Path $script:DeepWorkRoot 'Runs'))+'\'
    if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Run must be inside the owned local capture directory.'}
    Assert-DeepNoReparse $full
    $state=Get-Content -LiteralPath (Join-Path $full 'run.private.json') -Raw|ConvertFrom-Json
    if($state.Kind -ne 'USB4DeepCompareRun' -or $state.MachineHash -cne (Get-DeepMachineHash) -or $state.Run -ine $full){throw 'Run record does not match this Windows installation/path.'}
    return $state
}
function Stop-DeepOwnedTrace([string]$Directory) {
    $null=Assert-DeepRun $Directory;$path=Join-Path $Directory 'trace-status.json'
    if(-not(Test-Path -LiteralPath $path)){Write-Output 'No trace ownership record; no session was stopped.';return}
    $trace=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
    if($trace.Name -notmatch '^USB4_Ucsi_[a-f0-9]{12}$'){throw 'Unexpected trace ownership record.'}
    if(-not $trace.Stopped){Stop-ConnectionTrace $trace $Directory;Write-DeepJson $path $trace;if(-not $trace.Stopped){throw 'Owned trace did not stop.'}}
}
function Invoke-DeepCapture([object]$Context,[string]$Directory) {
    $status=[ordered]@{Schema=1;Kind='USB4DeepCompareCapture';Target=$Context.Target;Result='NotCompleted';Phase='DisconnectPrompt';Error=$null;ErrorDetail=$null;EvidenceErrors=@();Markers=@();Dump=$null;DumpBaselineQualified=$false;OwnerOutput=$null;Trace=$null;FirmwareCommandsSent=0;LiveKernelHelperLoaded=$false;SettingsChanged=$false;WirePacketsCaptured=$false;CoverageRequiresAnalysis=$true}
    $trace=$null
    try{
        $null=Read-Host 'Keep DEG2 powered. Disconnect its upstream cable from this laptop; press Enter when disconnected'
        $status.Phase='BeforeInventory'
        $before=Save-DeepInventory $Directory 'before';$initial=Get-DeepMilestone $before
        if($initial.RouterPresent -or $initial.BillboardPresent){throw 'DEG2 still appears attached. Capture stopped before tracing; preserve the state.'}
        Write-Host 'Saving firmware tables, driver identities and network state before connection.' -ForegroundColor Cyan
        $status.Phase='StaticInputs'
        Save-DeepInputs $Directory $Context
        Write-DeepJson (Join-Path $Directory 'network-before.private.json') (Get-DeepNetworkSnapshot)
        $status.Phase='TraceStartup'
        $trace=Start-ConnectionTrace $Directory;Write-DeepJson (Join-Path $Directory 'trace-status.json') $trace
        Start-Sleep -Seconds 5
        $status.Markers+=@{Name='ConnectPrompt';Utc=[DateTime]::UtcNow.ToString('o')}
        Write-Host 'GREEN: connect powered DEG2 to the SAME tested USB4 port now. Keep it connected through the dump step.' -ForegroundColor Green
        $status.Phase='PassiveAttachment'
        Start-Sleep -Seconds 45
        $status.Phase='AfterPassiveInventory';$after=Save-DeepInventory $Directory 'after-passive';$status.Milestone=Get-DeepMilestone $after
        $status.Markers+=@{Name='PassiveWindowEnd';Utc=[DateTime]::UtcNow.ToString('o')}
        Stop-ConnectionTrace $trace $Directory;Write-DeepJson (Join-Path $Directory 'trace-status.json') $trace
        if(-not $trace.Stopped){throw 'Trace did not stop; use STOP-TRACE.cmd on this laptop.'}
        $etl=Get-Item -LiteralPath (Join-Path $Directory 'connection.etl')
        if($etl.Length -eq 0 -or $etl.Length -ge 1GB){throw 'ETL missing/empty or at its cap; preserve this run before retrying.'}
        $status.EtlBytes=$etl.Length
        if($Context.Target -eq 'Dell' -and (-not $status.Milestone.RouterHealthy -or -not $status.Milestone.ExternalNvidiaBound)){$status.Result='WorkingDellControlNotEstablished';throw 'Working Dell router/GPU binding was not confirmed. No dump requested; preserve this unexpected baseline.'}
        if($Context.Target -eq 'Asus' -and ($status.Milestone.RouterPresent -or -not $status.Milestone.BillboardPresent)){$status.Result='ExpectedAsusFallbackNotEstablished';throw 'Expected attached ASUS fallback was not confirmed. Preserve this changed result; no automatic intervention.'}
        Complete-DeepDumpCapture $Context $Directory $status
    }catch{$status.Error=$_.Exception.Message;$status.ErrorDetail=@{Phase=$status.Phase;Id=$_.FullyQualifiedErrorId;Position=$_.InvocationInfo.PositionMessage;Stack=$_.ScriptStackTrace};Write-Warning $status.Error}
    finally{
        if($null -ne $trace){
            if(-not $trace.Stopped){try{Stop-ConnectionTrace $trace $Directory}catch{$status.EvidenceErrors+=@($_.Exception.Message)}}
            $status.Trace=$trace
            try{Write-DeepJson (Join-Path $Directory 'trace-status.json') $trace}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        }
        try{Write-DeepJson (Join-Path $Directory 'network-after.private.json') (Get-DeepNetworkSnapshot)}catch{$status.EvidenceErrors+=@($_.Exception.Message)}
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-DeepJson (Join-Path $Directory 'status.json') $status
    }
    return [pscustomobject]$status
}
function Assert-DeepTransport([string]$Directory,[string]$BundleId) {
    $full=Assert-LocalPath $Directory;Assert-DeepNoReparse $full
    $drive=Get-DeepDrive $full
    if($drive.Bus -ne 'USB' -or $drive.IsBoot -or $drive.IsSystem){throw 'Return destination must be the non-system USB drive containing this bundle.'}
    $manifest=Get-Content -LiteralPath (Join-Path $full 'bundle-manifest.json') -Raw|ConvertFrom-Json
    if($manifest.Kind -ne 'USB4DeepCompare' -or $manifest.BundleId -cne $BundleId){throw 'The original USB bundle identity does not match.'}
    return $drive
}
function Export-DeepReturn([string]$Directory,[string]$Transport) {
    $run=Assert-DeepRun $Directory;$null=Assert-DeepTransport $Transport $run.BundleId
    Stop-DeepOwnedTrace $Directory
    $status=Get-Content -LiteralPath (Join-Path $Directory 'status.json') -Raw|ConvertFrom-Json
    $inputs=@(Get-ChildItem -LiteralPath $Directory -File -Recurse|ForEach-Object {Assert-DeepNoReparse $_.FullName;[pscustomobject]@{Source=$_.FullName;Relative=$_.FullName.Substring($Directory.Length+1)}})
    if($null -ne $status.Dump){
        $dump=Read-DeepDumpHeader $status.Dump.Path ([datetime]::Parse($status.Dump.LastWriteUtc).ToUniversalTime().AddSeconds(-1))
        if($dump.Bytes -ne $status.Dump.Bytes -or $dump.LastWriteUtc -cne $status.Dump.LastWriteUtc){throw 'Saved dump changed before packaging.'}
        $inputs+=@([pscustomobject]@{Source=$dump.Path;Relative='Dump\full-live-kernel.dmp'})
    }
    $total=[long]0;foreach($evidenceItem in $inputs){Assert-DeepRelative $evidenceItem.Relative;$total+=(Get-Item -LiteralPath $evidenceItem.Source).Length}
    $localDrive=Get-DeepDrive $Directory
    if($localDrive.Bus -eq 'USB' -or $localDrive.FileSystem -ne 'NTFS' -or $localDrive.Free -lt [long]($total*1.02+2GB)){throw 'Insufficient local NTFS space to prepare the compressed return set. Original evidence retained.'}
    Initialize-DeepNative
    $id=[IO.Path]::GetFileName($Directory)+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
    $pack=Join-Path $script:DeepWorkRoot ('Packages\'+$id);$null=New-Item -ItemType Directory -Path $pack -Force
    $records=@();$ordinal=0
    Write-Host 'Compressing the private evidence on the laptop SSD. Original dump is retained. This can take several minutes.' -ForegroundColor Cyan
    foreach($evidenceItem in $inputs){
        $ordinal++;$name=$ordinal.ToString('D4')+'.gz';$gzip=Join-Path $pack $name
        Write-Host ('Compressing item '+$ordinal+' of '+$inputs.Count)
        $receipt=[Usb4DeepCompare.Native]::Compress($evidenceItem.Source,$gzip)
        $records+=@{RelativePath=$evidenceItem.Relative;RawBytes=$receipt.Bytes;RawSHA256=$receipt.Sha256;GzipFile=$name;GzipBytes=(Get-Item -LiteralPath $gzip).Length;GzipSHA256=(Get-FileHash -LiteralPath $gzip -Algorithm SHA256).Hash}
    }
    Write-DeepJson (Join-Path $pack 'package-index.private.json') @{Schema=1;Kind='USB4DeepComparePackage';Run=$Directory;Files=$records}
    $bytes=[long]0;foreach($record in $records){$bytes+=[long]$record.GzipBytes}
    $usbDrive=Assert-DeepTransport $Transport $run.BundleId
    if($usbDrive.Free -lt ($bytes+64MB)){throw ('Compressed set needs '+[Math]::Round($bytes/1GB,2)+' GiB, more than this USB has free. Capture and compressed set retained on the laptop; no result parts were copied.')}
    $returnRoot=Join-Path $Transport ('RETURNED\'+$id);$null=New-Item -ItemType Directory -Path $returnRoot -Force
    Write-DeepJson (Join-Path $returnRoot 'COPY-STARTED.private.json') @{Kind='USB4DeepCompareCopyStarted';Run=$Directory;ExpectedCompressedBytes=$bytes}
    $transportRecords=@()
    foreach($record in $records){
        $entry=[IO.Path]::GetFileNameWithoutExtension($record.GzipFile);$dest=Join-Path $returnRoot $entry;$null=New-Item -ItemType Directory -Path $dest
        $parts=@([Usb4DeepCompare.Native]::SplitCopy((Join-Path $pack $record.GzipFile),$dest,1GB))
        foreach($part in $parts){if((Get-FileHash -LiteralPath (Join-Path $dest $part.Name) -Algorithm SHA256).Hash -cne $part.Sha256){throw 'USB part read-back hash mismatch. Keep the laptop originals.'}}
        $transportRecords+=@{RelativePath=$record.RelativePath;RawBytes=$record.RawBytes;RawSHA256=$record.RawSHA256;GzipBytes=$record.GzipBytes;GzipSHA256=$record.GzipSHA256;PartDirectory=$entry;Parts=$parts}
    }
    Write-DeepJson (Join-Path $returnRoot 'RETURN-MANIFEST.private.json') @{Schema=1;Kind='USB4DeepCompareReturn';Complete=$true;Target=$run.Target;RunId=[IO.Path]::GetFileName($Directory);CaptureResult=$status.Result;FullDumpIncluded=($null -ne $status.Dump);Files=$transportRecords;OriginalsRetained=$true;CreatedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-Host ('RETURN COPY VERIFIED: '+$returnRoot) -ForegroundColor Green
    Write-Host 'Only a completed RETURN-MANIFEST qualifies the return copy. Keep laptop originals until analysis confirms import.'
    return $returnRoot
}

if($MyInvocation.InvocationName -eq '.'){return}
if($deepMode -eq 'Preview'){
    Write-Output 'Passive matched capture: model/USB4 guards, internal-SSD staging, ACPI tables and driver/network inventory, five-second baseline and 45-second attachment trace.'
    Write-Output 'Then the owner creates a Task Manager FULL live kernel dump while DEG2 remains attached. Automatic discovery/Browse handles the file, retries retain the trace, and FINISH-DUMP resumes a pending snapshot without recapture.'
    Write-Output 'No UCSI requests, LiveKD helper, driver/registry/boot/network changes. Return data is compressed on SSD and split into hash-verified <=1 GiB USB files.'
    Write-Output 'Preview performed no capture, staging or firmware operation.'
    exit 0
}
$bundle=Read-DeepBundle
if($deepMode -in @('Return','StopTrace','FinishDump')){
    if([string]::IsNullOrWhiteSpace($RunDirectory)){
        $link=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'latest-run.private.json') -Raw|ConvertFrom-Json
        if($link.MachineHash -cne (Get-DeepMachineHash) -or $link.BundleId -cne $bundle.BundleId){throw 'Return/cleanup link belongs to another Windows installation or bundle.'}
        $RunDirectory=$link.Run
    }
    if($deepMode -eq 'StopTrace'){Stop-DeepOwnedTrace $RunDirectory;exit 0}
    if([string]::IsNullOrWhiteSpace($TransportDirectory)){$TransportDirectory=$PSScriptRoot}
    if($deepMode -eq 'FinishDump'){
        $saved=Assert-DeepRun $RunDirectory;Stop-DeepOwnedTrace $RunDirectory
        $context=Get-DeepCaptureContext $saved.Target
        $status=Get-Content -LiteralPath (Join-Path $RunDirectory 'status.json') -Raw|ConvertFrom-Json
        try{Complete-DeepDumpCapture $context $RunDirectory $status}catch{$status.Error=$_.Exception.Message;$status.ErrorDetail=@{Phase=$status.Phase;Id=$_.FullyQualifiedErrorId;Stack=$_.ScriptStackTrace};Write-Warning $status.Error}
        finally{$status.FinishedUtc=[DateTime]::UtcNow.ToString('o');Write-DeepJson (Join-Path $RunDirectory 'status.json') $status}
    }
    $null=Export-DeepReturn $RunDirectory $TransportDirectory
    if($deepMode -eq 'FinishDump'){Write-Output ('Saved run result: '+$status.Result);if($status.Result -ne 'Captured_RequiresOfflinePolicyAndMemoryValidation' -or $null -ne $status.Error){exit 1}}
    exit 0
}
$context=Get-DeepCaptureContext $deepTarget
$sourceDrive=Get-DeepDrive $PSScriptRoot
if($sourceDrive.Bus -eq 'USB'){
    $null=Assert-DeepTransport $PSScriptRoot $bundle.BundleId
    $workDrive=Get-DeepDrive $script:DeepWorkRoot
    if($workDrive.Bus -eq 'USB' -or $workDrive.FileSystem -ne 'NTFS' -or $workDrive.Free -lt ($context.MemoryBytes+4GB)){throw 'Local NTFS SSD needs physical-RAM size plus 4 GiB free before snapshot capture. No setting changed.'}
    $stage=Join-Path $script:DeepWorkRoot ('Kits\'+[guid]::NewGuid().ToString('N'))
    Copy-DeepBundle $PSScriptRoot $stage
    Write-Host ('Verified SSD staging complete: '+$stage) -ForegroundColor Cyan
    & (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stage 'Capture-USB4DeepCompare.ps1') -Mode Capture -Target $deepTarget -TransportDirectory $PSScriptRoot
    exit $LASTEXITCODE
}
$captureDrive=Get-DeepDrive $script:DeepWorkRoot
if($captureDrive.Bus -eq 'USB' -or $captureDrive.FileSystem -ne 'NTFS' -or $captureDrive.Free -lt ($context.MemoryBytes+4GB)){throw 'Capture requires internal NTFS storage with physical-RAM size plus 4 GiB free.'}
if([string]::IsNullOrWhiteSpace($TransportDirectory)){throw 'Start from the USB bundle so its return destination can be verified.'}
$null=Assert-DeepTransport $TransportDirectory $bundle.BundleId
$run=Join-Path $script:DeepWorkRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+$deepTarget+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$null=New-Item -ItemType Directory -Path $run -Force;Assert-DeepNoReparse $run
$record=@{Schema=1;Kind='USB4DeepCompareRun';Run=$run;Target=$deepTarget;MachineHash=$context.MachineHash;BundleId=$bundle.BundleId;Transport=$TransportDirectory;StartedUtc=[DateTime]::UtcNow.ToString('o')}
Write-DeepJson (Join-Path $run 'run.private.json') $record
[IO.File]::Copy((Join-Path $PSScriptRoot 'bundle-manifest.json'),(Join-Path $run 'bundle-manifest.json'),$false)
Write-DeepJson (Join-Path $TransportDirectory 'latest-run.private.json') $record
$result=Invoke-DeepCapture $context $run
Write-Host ('Capture: '+$result.Result+'; laptop originals: '+$run)
try{$null=Export-DeepReturn $run $TransportDirectory}catch{Write-Warning ('Return copy incomplete: '+$_.Exception.Message);Write-Warning 'Laptop originals are retained. RETURN.cmd on the same laptop can retry packaging.';exit 1}
if($result.Result -ne 'Captured_RequiresOfflinePolicyAndMemoryValidation' -or $result.EvidenceErrors.Count){exit 1}
exit 0
