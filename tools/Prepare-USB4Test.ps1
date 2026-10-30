#requires -Version 5.1
<#
Build an isolated native-boot Windows VHDX on this FA507XI. Preview is read-only.
Prepare creates/formats only the new 64 GiB virtual disk and services it offline.
AddBoot creates one explicit boot entry; original default/order of existing entries
and UEFI boot files are preserved. No automatic restart or firmware installation.
RemoveBoot removes only the verified toolkit entry. It retains all files/results.
#>
[CmdletBinding()]
param(
    [ValidateSet('Preview','Prepare','AddBoot','RemoveBoot')][string]$Mode='Preview',
    [string]$ImagePath,
    [ValidateRange(0,100)][int]$Index=0
)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'NativeBoot.Common.ps1')
Assert-ASUSModel
$repo = Split-Path -Parent $PSScriptRoot
$privateRoot = Join-Path $repo 'local'
$testRoot = Join-Path $privateRoot 'NativeBoot'
$driverRoot = Join-Path $privateRoot 'Drivers'
$statePath = Join-Path $testRoot 'state.json'
$vhdPath = Join-Path $testRoot 'USB4-Test.vhdx'
$null = Assert-ContainedPath -Path $vhdPath -Parent $privateRoot
Assert-NoReparseAncestor $testRoot

function Find-InstallerImages {
    return @(foreach($drive in [IO.DriveInfo]::GetDrives()) {
        if (-not $drive.IsReady) { continue }
        foreach($name in @('install.wim','install.esd','install.swm')) {
            $candidate = Join-Path $drive.RootDirectory.FullName ('sources\'+$name)
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $candidate }
        }
    })
}

function Assert-DriverBundle {
    $manifestPath=Join-Path $driverRoot 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Missing local baseline driver bundle.' }
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.Schema -ne 1 -or $manifest.Model -ne 'FA507XI' -or @($manifest.Packages).Count -ne 7) { throw 'Unexpected driver manifest.' }
    $expectedNames=@('amdi2c.inf','amdgpio2.inf','amdmicropep.inf','amdppmpf.inf','asussci2.inf','prspbdrv.inf','prhiddrv.inf')
    $seen=@()
    foreach($package in $manifest.Packages) {
        $inf=Assert-ContainedPath -Path (Join-Path $driverRoot $package.Inf) -Parent $driverRoot
        Assert-NoReparseAncestor $inf
        $name=[IO.Path]::GetFileName($inf).ToLowerInvariant()
        if($expectedNames -notcontains $name -or $seen -contains $name){throw 'Unexpected or duplicate driver package.'}
        $seen+=$name
        $contents=Get-Content -LiteralPath $inf -Raw
        if($contents -notmatch '(?im)^\s*Class\s*=\s*System\s*$'){throw 'Only System-class packages are permitted.'}
        if((Get-FileHash -LiteralPath $inf -Algorithm SHA256).Hash -ne $package.InfSHA256){throw 'Driver INF hash mismatch.'}
        foreach($file in $package.Files) {
            $path=Assert-ContainedPath -Path (Join-Path $driverRoot $file.Path) -Parent $driverRoot
            Assert-NoReparseAncestor $path
            if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.SHA256){throw 'Driver file hash mismatch.'}
        }
        $catalogs=@(Get-ChildItem -LiteralPath (Split-Path -Parent $inf) -File -Filter '*.cat')
        if($catalogs.Count -ne 1 -or (Get-AuthenticodeSignature -LiteralPath $catalogs[0].FullName).Status -ne 'Valid'){throw 'Driver catalog signature validation failed.'}
    }
    return $manifest
}

if($Mode -eq 'Preview') {
    [pscustomobject]@{
        Mode='Preview - no changes'; Model='FA507XI'; VirtualDisk=$vhdPath
        StateExists=(Test-Path -LiteralPath $statePath)
        InstallerImages=@(Find-InstallerImages)
        DriverBundlePresent=(Test-Path -LiteralPath (Join-Path $driverRoot 'manifest.json'))
        HostFreeGB=[math]::Round((New-Object IO.DriveInfo([IO.Path]::GetPathRoot($vhdPath))).AvailableFreeSpace/1GB,1)
    } | Format-List
    exit 0
}
Assert-Administrator
$bcd=Join-Path $env:SystemRoot 'System32\bcdedit.exe'
if($Mode -in @('AddBoot','RemoveBoot')) {
    if(-not (Test-Path -LiteralPath $statePath)){throw 'No saved preparation state.'}
    $state=Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    if($state.Schema -ne 1 -or $state.Model -ne 'FA507XI' -or $state.VhdPath -ne $vhdPath){throw 'Saved state does not belong to this test directory.'}
    $null=Get-BootEntryArguments -Id $state.BootId -VhdPath $vhdPath
    if($Mode -eq 'RemoveBoot') {
        if($state.Phase -notin @('BootEntryCreated','BootEntryPending')){throw 'No recorded boot entry needs removal.'}
        $entry=Invoke-NativeChecked -File $bcd -Arguments @('/enum',$state.BootId,'/v')
        $owned=Test-BootEntryOwnership -Text $entry -Id $state.BootId -VhdPath $vhdPath
        # A create can succeed before setting device fails. The preallocated GUID
        # was checked absent and persisted before creation; retain a partial-entry
        # recovery path without accepting a reserved/current GUID or another label.
        $partialOwned=($state.Phase -eq 'BootEntryPending' -and $entry.Contains($state.BootId) -and $entry.Contains('USB4 test - temporary Windows'))
        if(-not $owned -and -not $partialOwned){throw 'Boot entry ownership check failed. No entry deleted.'}
        $current=Invoke-NativeChecked -File $bcd -Arguments @('/enum','{current}','/v')
        if($current.Contains($state.BootId)){throw 'Boot back into the original Windows before removing its test entry.'}
        $null=Invoke-NativeChecked -File $bcd -Arguments @('/delete',$state.BootId,'/cleanup')
        $state.Phase='BootEntryRemoved'; Save-TestState -Path $statePath -State $state
        Write-Host 'Removed the test boot entry. VHDX and results retained.'
        exit 0
    }
    if($state.Phase -ne 'ImagePrepared'){throw 'The image is not in the prepared state, or a boot operation was already attempted.'}
    if(-not (Test-Path -LiteralPath $vhdPath -PathType Leaf)){throw 'Prepared VHDX missing.'}
    if((Get-DiskImage -ImagePath $vhdPath).Attached){throw 'Detach the test VHDX before adding its boot entry.'}
    $before=Invoke-NativeChecked -File $bcd -Arguments @('/enum','all','/v')
    if($before.Contains($state.BootId)){throw 'The allocated boot GUID already exists.'}
    $null=Invoke-NativeChecked -File $bcd -Arguments @('/export',(Join-Path $testRoot 'BCD-before-test.backup'))
    [IO.File]::WriteAllText((Join-Path $testRoot 'BCD-before-test.txt'),$before)
    $state.Phase='BootEntryPending'; Save-TestState -Path $statePath -State $state
    foreach($arguments in (Get-BootEntryArguments -Id $state.BootId -VhdPath $vhdPath)) {
        $null=Invoke-NativeChecked -File $bcd -Arguments $arguments
    }
    $entry=Invoke-NativeChecked -File $bcd -Arguments @('/enum',$state.BootId,'/v')
    if(-not (Test-BootEntryOwnership -Text $entry -Id $state.BootId -VhdPath $vhdPath)){throw 'New entry did not verify.'}
    $state.Phase='BootEntryCreated'; Save-TestState -Path $statePath -State $state
    Write-Host 'Created USB4 test - temporary Windows. Original default retained. No restart performed.'
    Write-Host 'When ready, restart and select the temporary Windows entry. First boot may restart; select it again.'
    Write-Host 'If your boot menu timeout is zero, use Windows Advanced startup > Use another operating system.'
    Write-Host ('Test entry: '+$state.BootId)
    exit 0
}

if(Test-Path -LiteralPath $statePath){throw 'Preparation state already exists. Review it before creating another image.'}
if(Test-Path -LiteralPath $vhdPath){throw 'A VHDX already exists at the target. It will not be overwritten.'}
if(-not $ImagePath) {
    $images=@(Find-InstallerImages)
    if($images.Count -ne 1){throw 'Connect one installer USB, or specify its sources\install.wim, install.esd, or first install.swm using -ImagePath.'}
    $ImagePath=$images[0]
}
$ImagePath=(Resolve-Path -LiteralPath $ImagePath).ProviderPath
if($ImagePath -notmatch '\.(wim|esd|swm)$'){throw 'Use a Windows installation image, not boot.wim or an ISO filename.'}
if([IO.Path]::GetFileName($ImagePath) -ieq 'boot.wim'){throw 'WinPE boot.wim is not a full Windows image.'}
$hostDrive=New-Object IO.DriveInfo([IO.Path]::GetPathRoot($vhdPath))
if($hostDrive.DriveType -ne 'Fixed' -or $hostDrive.DriveFormat -ne 'NTFS' -or $hostDrive.AvailableFreeSpace -lt 75GB){throw 'The host must be a fixed NTFS volume with at least 75 GiB free.'}
$encryption=Get-BitLockerVolume -MountPoint $hostDrive.Name -ErrorAction Stop
if([string]$encryption.VolumeStatus -ne 'FullyDecrypted' -or $encryption.EncryptionPercentage -ne 0){throw 'Native VHDX boot requires a fully decrypted hosting volume.'}
$manifest=Assert-DriverBundle
$details=@()
if($Index -eq 0) {
    foreach($summary in @(Get-WindowsImage -ImagePath $ImagePath -ErrorAction Stop)) {
        $detail=Get-WindowsImage -ImagePath $ImagePath -Index $summary.ImageIndex -ErrorAction Stop
        if($detail.EditionId -eq 'Professional' -and [int]$detail.Architecture -eq 9){$details+=$detail}
    }
    if($details.Count -ne 1){throw 'Could not select exactly one x64 Professional image. Specify -Index after reviewing the media.'}
    $Index=[int]$details[0].ImageIndex
} else { $details=@(Get-WindowsImage -ImagePath $ImagePath -Index $Index -ErrorAction Stop) }
$detail=$details[0]
$imageVersion=[version]$detail.Version
$hostVersion=[version]('10.0.'+[string](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild+'.0')
if([int]$detail.Architecture -ne 9 -or $detail.EditionId -ne 'Professional' -or $imageVersion.Build -lt 22621 -or $imageVersion.Build -gt $hostVersion.Build){throw 'Use an x64 Windows 11 Pro image no newer than the current boot environment.'}
if($vhdPath -notmatch '^[A-Za-z]:\\[A-Za-z0-9_ .\\-]+\.vhdx$'){throw 'The diskpart creation path must use ordinary ASCII directory names.'}
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Assert-NoReparseAncestor $testRoot
$state=[pscustomobject]@{
    Schema=1; Model='FA507XI'; Phase='Creating'; VhdPath=$vhdPath
    BridgeId=[guid]::NewGuid().ToString(); BootId=('{'+[guid]::NewGuid().ToString()+'}')
    ImagePath=$ImagePath; ImageIndex=$Index; ImageVersion=[string]$imageVersion
    CreatedUtc=[DateTime]::UtcNow.ToString('o'); Error=''
}
Save-TestState -Path $statePath -State $state
$diskpartFile=Join-Path $testRoot 'create-vhdx.txt'
[IO.File]::WriteAllLines($diskpartFile,[string[]](Get-VhdCreationCommands $vhdPath),[Text.Encoding]::ASCII)
$mounted=$false
try {
    Write-Host ('Creating only this new virtual disk: '+$vhdPath) -ForegroundColor Cyan
    $null=Invoke-NativeChecked -File (Join-Path $env:SystemRoot 'System32\diskpart.exe') -Arguments @('/s',$diskpartFile) -LogPath (Join-Path $testRoot 'create-vhdx.log')
    if(-not (Test-Path -LiteralPath $vhdPath -PathType Leaf)){throw 'Diskpart did not create the VHDX.'}
    $image=Mount-DiskImage -ImagePath $vhdPath -Access ReadWrite -PassThru -ErrorAction Stop
    $mounted=$true
    $disk=@($image|Get-Disk -ErrorAction Stop)
    if($disk.Count -ne 1){throw 'New VHDX did not resolve to one disk.'}
    $number=[int]$disk[0].Number
    $null=Assert-VirtualDiskTarget -ImagePath $vhdPath -DiskNumber $number -RequireRaw
    Initialize-Disk -Number $number -PartitionStyle GPT -ErrorAction Stop | Out-Null
    $null=Assert-VirtualDiskTarget -ImagePath $vhdPath -DiskNumber $number
    $partition=New-Partition -DiskNumber $number -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
    $null=Assert-VirtualDiskTarget -ImagePath $vhdPath -DiskNumber $number
    if($partition.DiskNumber -ne $number -or -not $partition.DriveLetter){throw 'New virtual partition did not verify.'}
    $partition | Format-Volume -FileSystem NTFS -NewFileSystemLabel 'USB4Test' -Confirm:$false -ErrorAction Stop | Out-Null
    $mountRoot=([string]$partition.DriveLetter)+':\'
    if($mountRoot -ieq ($env:SystemDrive+'\')){throw 'The target must not be the running operating system.'}
    $state.Phase='ApplyingImage'; Save-TestState -Path $statePath -State $state
    $applyArgs=@('/Apply-Image',('/ImageFile:'+$ImagePath),('/Index:'+$Index),('/ApplyDir:'+$mountRoot),'/CheckIntegrity','/Verify','/English',('/LogPath:'+(Join-Path $testRoot 'apply-image.log')))
    if($ImagePath -match '\.swm$'){$applyArgs+=('/SWMFile:'+(Join-Path (Split-Path -Parent $ImagePath) 'install*.swm'))}
    Write-Host 'Applying the full Windows image. This can take several minutes; see local\NativeBoot\apply-image.log.' -ForegroundColor Cyan
    $null=Invoke-NativeChecked -File (Join-Path $env:SystemRoot 'System32\dism.exe') -Arguments $applyArgs -LogPath (Join-Path $testRoot 'apply-image-output.log')
    if(-not (Test-Path -LiteralPath (Join-Path $mountRoot 'Windows\System32\winload.efi'))){throw 'Windows image did not produce the expected boot loader.'}
    foreach($package in $manifest.Packages) {
        Write-Host ('Adding baseline System driver: '+[IO.Path]::GetFileName($package.Inf))
        Add-WindowsDriver -Path $mountRoot -Driver (Join-Path $driverRoot $package.Inf) -ErrorAction Stop | Out-Null
    }
    $testTools=Join-Path $mountRoot 'USB4Test'
    New-Item -ItemType Directory -Path $testTools -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Collect-USB4Test.ps1') -Destination $testTools
    $repoRelative=$repo.Substring($hostDrive.RootDirectory.FullName.Length)
    $bridge=[pscustomobject]@{Schema=1;BridgeId=$state.BridgeId;RepositoryRelativePath=$repoRelative}
    $bridge|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $testTools 'bridge.json') -Encoding UTF8
    $bridge|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $testRoot 'bridge.json') -Encoding UTF8
    $panther=Join-Path $mountRoot 'Windows\Panther\Unattend'
    New-Item -ItemType Directory -Path $panther -Force | Out-Null
    $answer='<?xml version="1.0" encoding="utf-8"?><unattend xmlns="urn:schemas-microsoft-com:unattend"><settings pass="oobeSystem"><component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS"><Reseal><Mode>Audit</Mode><ForceShutdownNow>false</ForceShutdownNow></Reseal></component></settings></unattend>'
    [xml]$answerCheck=$answer
    [IO.File]::WriteAllText((Join-Path $panther 'Unattend.xml'),$answer,(New-Object Text.UTF8Encoding($false)))
    $desktop=Join-Path $mountRoot 'Users\Public\Desktop'
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null
    [IO.File]::WriteAllLines((Join-Path $desktop 'Run USB4 diagnostic.cmd'),@('@echo off','powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SystemDrive%\USB4Test\Collect-USB4Test.ps1"','pause'),[Text.Encoding]::ASCII)
    $state.Phase='ImagePrepared'; Save-TestState -Path $statePath -State $state
} catch {
    $state.Error=$_.Exception.Message
    Save-TestState -Path $statePath -State $state
    throw
} finally {
    if($mounted){Dismount-DiskImage -ImagePath $vhdPath -ErrorAction Stop}
}
Write-Host 'Image prepared and detached. Boot configuration has not been changed.' -ForegroundColor Green
Write-Host 'Review local\NativeBoot\state.json, then use -Mode AddBoot to create the temporary entry.'
