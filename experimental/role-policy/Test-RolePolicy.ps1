#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Preview','Preflight','Install','Observe','Rollback')][string]$Mode='Preview',
      [string]$PackageDirectory='', [string]$ReviewedDriverSHA256='',
      [string]$SignTool='', [string]$TraceFmt='', [string]$TmfDirectory='', [string]$RunDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$rpMode=$Mode
. (Join-Path $PSScriptRoot '..\..\tools\Capture-USB4DeepCompare.ps1')
$script:RpRoot=Join-Path $repo 'local\RolePolicyTest'
$script:RpInfHash=(Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Usb4RolePolicy.inf') -Algorithm SHA256).Hash
$script:RpClientHash='436C580CE96861187A5299F00EAB9E852EFA6B33F127D59819C5283B6482EA4E'
$script:RpTmfName='786c5291-0ae4-3c83-30a1-a1f646072d04.tmf'
$script:RpTmfHash='2EC657C6C97542F084A91021ACED9985127B3CD1667F29A4AA52B4671A61234F'

function Get-RpHost {
    $context=Get-DeepCaptureContext 'Asus'
    $bios=Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS'
    $version=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    if([string]$bios.BIOSVersion -notmatch '(^|[^0-9])314([^0-9]|$)' -or [string]$version.CurrentBuildNumber -ne '26200' -or $version.UBR -ne 9818){throw 'This experiment is pinned to the analysed BIOS 314 / Windows 26200.9818.'}
    $client=Resolve-DeepDriverPath 'UcmUcsiAcpiClient.sys'
    if((Get-FileHash -LiteralPath $client -Algorithm SHA256).Hash -cne $script:RpClientHash){throw 'Analysed ACPI client image changed.'}
    if(-not(Confirm-SecureBootUEFI)){throw 'This runner requires Secure Boot to remain enabled; it never changes boot security.'}
    $p=Get-DeepPnpProperties $context.UcsiInstance @('DEVPKEY_Device_DriverInfPath','DEVPKEY_Device_LowerFilters','DEVPKEY_Device_UpperFilters')
    $base=[string]$p.Values['DEVPKEY_Device_DriverInfPath']
    if([string]::IsNullOrWhiteSpace($base)){throw 'Cannot identify the Microsoft base package.'}
    return [pscustomobject]@{Context=$context;BaseInf=$base;Lower=@($p.Values['DEVPKEY_Device_LowerFilters']);Upper=@($p.Values['DEVPKEY_Device_UpperFilters'])}
}
function Get-RpOwnedPackages {
    return @(Get-WindowsDriver -Online -All -ErrorAction Stop | Where-Object {
        [IO.Path]::GetFileName([string]$_.OriginalFileName) -ieq 'Usb4RolePolicy.inf'
    })
}
function Assert-RpOwnedPackage([object]$Driver,[string]$Hash,[string]$SysHash='') {
    if($Driver.Driver -notmatch '^oem[0-9]+\.inf$' -or $Driver.ProviderName -ne 'USB4 Research Experiment' -or
       [string]$Driver.Version -ne '0.1.0.0' -or $Driver.ClassName -ne 'Extension' -or
       (Get-FileHash -LiteralPath $Driver.OriginalFileName -Algorithm SHA256).Hash -cne $Hash){throw 'Owned extension package identity/hash is ambiguous. No package will be removed.'}
    if($SysHash -and (Get-FileHash -LiteralPath (Join-Path (Split-Path $Driver.OriginalFileName -Parent) 'Usb4RolePolicy.sys')).Hash -cne $SysHash){throw 'Owned driver binary changed. Stop for package review.'}
}
function Get-RpBootStamp {return (Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToUniversalTime().ToString('o')}
function Assert-RpDisconnected {
    if((Read-Host 'Disconnect ALL USB-C cables from ASUS; keep barrel power and existing Ethernet. Type DISCONNECTED') -cne 'DISCONNECTED'){throw 'Disconnection was not confirmed.'}
    $devices=@(Get-PnpDevice -PresentOnly)
    if(@($devices|Where-Object {$_.InstanceId -match '^USB4\\VID_8087&PID_5786|^USB\\VID_041F&PID_D002|^PCI\\VEN_10DE&DEV_2702'}).Count){throw 'DEG2-related devices remain present. Stop without another device operation.'}
}
function Assert-RpSignedPackage([string]$Directory,[string]$ExpectedSHA,[string]$Verifier) {
    if($ExpectedSHA -notmatch '^[A-Fa-f0-9]{64}$'){throw 'An independently reviewed signed SYS hash is required.'}
    $path=Assert-LocalPath $Directory;Assert-DeepNoReparse $path
    foreach($name in @('Usb4RolePolicy.inf','Usb4RolePolicy.sys','Usb4RolePolicy.cat')){
        $file=Join-Path $path $name
        if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw ('Missing package member '+$name)}
        Assert-DeepNoReparse $file
    }
    if((Get-FileHash -LiteralPath (Join-Path $path 'Usb4RolePolicy.inf') -Algorithm SHA256).Hash -cne $script:RpInfHash -or
       (Get-FileHash -LiteralPath (Join-Path $path 'Usb4RolePolicy.sys') -Algorithm SHA256).Hash -ine $ExpectedSHA){throw 'Package differs from the reviewed source/package.'}
    $cat=Join-Path $path 'Usb4RolePolicy.cat';$signature=Get-AuthenticodeSignature -LiteralPath $cat
    if($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
       $signature.SignerCertificate.Subject -notmatch 'O=Microsoft Corporation(?:,|$)'){throw 'A Microsoft-signed valid catalog is required. Unsigned/test-signed packages are refused before any change.'}
    $verified=Assert-MicrosoftExecutable $Verifier 'signtool.exe'
    foreach($member in @('Usb4RolePolicy.sys','Usb4RolePolicy.inf')){
        $result=& $verified verify /kp /v /c $cat (Join-Path $path $member) 2>&1
        if($LASTEXITCODE -ne 0){throw ('Kernel-policy catalog verification failed: '+($result -join ' '))}
    }
    return $path
}
function Assert-RpDecoder([string]$Executable,[string]$Directory) {
    $null=Assert-MicrosoftExecutable $Executable 'tracefmt.exe'
    Assert-DeepNoReparse $Directory
    if((Get-FileHash -LiteralPath (Join-Path $Directory $script:RpTmfName) -Algorithm SHA256).Hash -cne $script:RpTmfHash){throw 'Matching ACPI-client trace formats are required.'}
}
function Get-RpPreflight([string]$Package,[string]$Hash,[string]$Verifier,[string]$Decoder,[string]$Tmfs) {
    # The signing gate intentionally precedes host inventory, checkpoints and all writes.
    $verified=Assert-RpSignedPackage $Package $Hash $Verifier
    Assert-RpDecoder $Decoder $Tmfs
    $hostState=Get-RpHost
    if(@(Get-RpOwnedPackages).Count -or (Test-Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Usb4RolePolicy')){throw 'An earlier experiment package/service exists. Review its saved run and rollback first.'}
    if(Test-Path -LiteralPath $script:RpRoot){
        foreach($prior in @(Get-ChildItem -LiteralPath $script:RpRoot -Directory)){
            Assert-DeepNoReparse $prior.FullName
            $saved=Join-Path $prior.FullName 'state.private.json'
            if(Test-Path -LiteralPath $saved){
                $old=Get-Content -LiteralPath $saved -Raw|ConvertFrom-Json
                if($old.Kind -ne 'Usb4RolePolicyRun' -or $old.PendingRollback){throw 'A previous run still needs rollback/review. Do not create another experiment.'}
            }
        }
    }
    if(@($hostState.Lower|Where-Object {$_}).Count -or @($hostState.Upper|Where-Object {$_}).Count){throw 'Unexpected UCSI filter configuration.'}
    $ccPath=Join-Path $repo 'local\UcsiMemoryProbe\initial-role-test-state.json'
    if(-not(Test-Path -LiteralPath $ccPath)){throw 'Retained default-DRP restoration record is required.'}
    $cc=Get-Content -LiteralPath $ccPath -Raw|ConvertFrom-Json
    if($cc.Kind -ne 'FA507XIInitialRoleTest' -or $cc.Schema -ne 1 -or $cc.RestoreRequired -or
       $cc.Phase -ne 'DefaultDrpRestored' -or $cc.UcsiInstance -cne $hostState.Context.UcsiInstance){throw 'Matching default-DRP restoration is not proven.'}
    return [pscustomobject]@{Package=$verified;HostState=$hostState;SysHash=(Get-FileHash -LiteralPath (Join-Path $verified 'Usb4RolePolicy.sys')).Hash;BootStamp=(Get-RpBootStamp)}
}
function Invoke-RpPnp([string[]]$Arguments,[string]$LogPath) {
    $output=& (Join-Path $env:SystemRoot 'System32\pnputil.exe') @Arguments 2>&1
    $code=$LASTEXITCODE
    [IO.File]::WriteAllText($LogPath,($output -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    if($code -notin @(0,3010)){throw ('PnP operation failed with '+$code+'. Check the saved log; rollback remains pending.')}
    return $code
}
function Start-RpTrace([string]$Directory) {
    $null=[IO.Directory]::CreateDirectory($Directory)
    return Start-ConnectionTrace $Directory
}
function Invoke-RpDeviceChange([string]$Directory,[scriptblock]$Action,[bool]$AllowWithoutTrace=$false) {
    $trace=$null
    try{
        try{$trace=Start-RpTrace $Directory}catch{
            if(-not $AllowWithoutTrace){throw}
            Write-Warning 'Recovery tracing unavailable. Package removal still runs; restoration will remain unverified.'
        }
        if($null -ne $trace){Write-DeepJson (Join-Path $Directory 'trace.private.json') $trace}
        & $Action
    }finally{
        if($null -ne $trace){
            Stop-ConnectionTrace $trace $Directory
            Write-DeepJson (Join-Path $Directory 'trace.private.json') $trace
            if(-not $trace.Stopped){throw 'Owned ETW session did not stop. Use its recorded exact session name; do not stop other sessions.'}
        }
    }
}
function Test-RpPolicyText([string]$Text,[string]$Summary,[bool]$Enabled) {
    if($Summary -notmatch '(?m)^Total Events\s+Lost\s+0\s*$' -or $Summary -notmatch '(?m)^Total Format\s+Errors\s+0\s*$'){return $false}
    $forced='Data role correction policy disabled. Forced UsbDeviceControllerEnabled:true.'
    if($Enabled){return $Text.Contains($forced) -and ($Text -notmatch 'UsbDeviceControllerEnabled:false')}
    return (-not $Text.Contains($forced)) -and ($Text -match 'UsbDeviceControllerEnabled:false')
}
function Assert-RpPolicyTrace([string]$Directory,[bool]$Enabled,[string]$Decoder,[string]$Tmfs) {
    Assert-RpDecoder $Decoder $Tmfs
    $trace=Get-Content -LiteralPath (Join-Path $Directory 'trace.private.json') -Raw|ConvertFrom-Json
    if(-not $trace.Stopped -or $trace.StopExitCode -ne 0){throw 'Startup trace is incomplete.'}
    $decoded=Join-Path $Directory ('policy-'+[guid]::NewGuid().ToString('N')+'.private.txt')
    $output=& $Decoder (Join-Path $Directory 'connection.etl') -p $Tmfs -o $decoded -gmt 2>&1
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath ($decoded+'.sum'))){throw 'Trace decoding did not produce its summary.'}
    if(-not(Test-RpPolicyText ([IO.File]::ReadAllText($decoded)) ([IO.File]::ReadAllText($decoded+'.sum')) $Enabled)){throw 'Microsoft startup policy acceptance/restoration is not proven. Do not attach DEG2.'}
    return [pscustomobject]@{ExpectedDisabled=$Enabled;TraceSHA256=(Get-FileHash -LiteralPath (Join-Path $Directory 'connection.etl')).Hash;DecodedSHA256=(Get-FileHash -LiteralPath $decoded).Hash}
}
function Read-RpRun([string]$Directory,[switch]$ForRollback) {
    $full=Assert-LocalPath $Directory;Assert-DeepNoReparse $full
    if(-not $full.StartsWith(([IO.Path]::GetFullPath($script:RpRoot)+'\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Run must be inside the owned local/RolePolicyTest directory.'}
    $state=Get-Content -LiteralPath (Join-Path $full 'state.private.json') -Raw|ConvertFrom-Json
    if($state.Kind -ne 'Usb4RolePolicyRun' -or $state.Schema -ne 1){throw 'Unexpected saved run.'}
    if($ForRollback){
        # Recovery must remain reachable when the filtered device has an error.
        $principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Rollback requires Administrator Windows PowerShell.'}
        $bios=Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS'
        if($bios.SystemManufacturer -notmatch 'ASUS|ASUSTeK' -or $bios.SystemProductName -notmatch '(?i)(^|[^a-z0-9])FA507XI([^a-z0-9]|$)' -or
           $state.MachineHash -cne (Get-DeepMachineHash) -or $state.Target -notmatch '^ACPI\\USBC000\\[^\\]+$'){throw 'Recovery record belongs to another machine/target.'}
    }else{
        $hostState=Get-RpHost
        if($state.MachineHash -cne $hostState.Context.MachineHash -or $state.Target -cne $hostState.Context.UcsiInstance -or $state.BaseInf -ine $hostState.BaseInf){throw 'Saved run does not match this machine/UCSI base binding.'}
    }
    return $state
}
function Assert-RpSharing([object]$Before,[object]$After) {
    $a=@($Before.Sharing|Where-Object Shared|Sort-Object Guid|Select-Object Guid,Type)|ConvertTo-Json -Compress
    $b=@($After.Sharing|Where-Object Shared|Sort-Object Guid|Select-Object Guid,Type)|ConvertTo-Json -Compress
    if($a -cne $b){throw 'Enabled ICS bindings changed. Review snapshots; this script does not rewrite networking.'}
}
function Invoke-RpInstall([object]$Preflight,[string]$Decoder,[string]$Tmfs) {
    Assert-RpDisconnected
    if((Read-Host 'Windows must be responsive and work saved. Type STABLE to install this one experimental filter') -cne 'STABLE'){throw 'Stable baseline was not confirmed.'}
    $run=Join-Path $script:RpRoot ([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
    $null=[IO.Directory]::CreateDirectory($run)
    $before=Get-DeepNetworkSnapshot;Write-DeepJson (Join-Path $run 'network-before.private.json') $before
    $state=[ordered]@{Schema=1;Kind='Usb4RolePolicyRun';MachineHash=$Preflight.HostState.Context.MachineHash;Target=$Preflight.HostState.Context.UcsiInstance;BaseInf=$Preflight.HostState.BaseInf;InfHash=$script:RpInfHash;SysHash=$Preflight.SysHash;BootStamp=$Preflight.BootStamp;PublishedInf=$null;PendingRollback=$true;Phase='InstallIntent';PolicyProof=$null;Observation=$null;RollbackProof=$null;StartedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-DeepJson (Join-Path $run 'state.private.json') $state
    Write-Host ('Recovery run: '+$run+' ; use -Mode Rollback -RunDirectory with this exact directory.')
    try{
        Invoke-RpDeviceChange (Join-Path $run 'startup') {
            $code=Invoke-RpPnp @('/add-driver',(Join-Path $Preflight.Package 'Usb4RolePolicy.inf'),'/install') (Join-Path $run 'install.private.txt')
            $owned=@(Get-RpOwnedPackages)
            if($owned.Count -ne 1){throw 'Cannot uniquely identify the newly added package.'}
            Assert-RpOwnedPackage $owned[0] $state.InfHash $state.SysHash
            $state.PublishedInf=$owned[0].Driver;Write-DeepJson (Join-Path $run 'state.private.json') $state
            if($code -eq 3010){throw 'Installation requires a reboot. No automatic reboot or DEG2 attachment; rollback/review is pending.'}
            if((Invoke-RpPnp @('/restart-device',$state.Target) (Join-Path $run 'restart.private.txt')) -eq 3010){throw 'Device restart requires reboot; do not attach.'}
            Start-Sleep -Seconds 4
        }
        $state.PolicyProof=Assert-RpPolicyTrace (Join-Path $run 'startup') $true $Decoder $Tmfs
        $after=Get-DeepNetworkSnapshot;Write-DeepJson (Join-Path $run 'network-after-install.private.json') $after
        Assert-RpSharing $before $after
        $state.Phase='PolicyAcceptedBeforeAttachment'
    }catch{$state.Phase='InstallNeedsRollback';throw}finally{Write-DeepJson (Join-Path $run 'state.private.json') $state}
    return $run
}
function Invoke-RpObserve([string]$Directory) {
    $state=Read-RpRun $Directory
    if(-not $state.PendingRollback -or $state.Phase -ne 'PolicyAcceptedBeforeAttachment' -or $null -eq $state.PolicyProof){throw 'This run is not ready for a single attachment.'}
    if($state.BootStamp -cne (Get-RpBootStamp) -or ([DateTime]::UtcNow-[DateTime]::Parse($state.StartedUtc).ToUniversalTime()).TotalMinutes -gt 15){throw 'Policy proof must be in the same boot and within 15 minutes. Roll back; do not reuse stale proof.'}
    if((Get-FileHash -LiteralPath (Join-Path $Directory 'startup\connection.etl')).Hash -cne $state.PolicyProof.TraceSHA256){throw 'Startup evidence changed.'}
    $owned=@(Get-RpOwnedPackages)
    if($owned.Count -ne 1 -or $owned[0].Driver -ine $state.PublishedInf){throw 'Experiment package changed.'}
    Assert-RpOwnedPackage $owned[0] $state.InfHash $state.SysHash
    $driver=Get-CimInstance Win32_SystemDriver -Filter "Name='Usb4RolePolicy'"
    if($null -eq $driver -or $driver.State -ne 'Running'){throw 'Experimental filter is not running.'}
    Assert-RpDisconnected
    $state.Phase='AttachmentIntent';Write-DeepJson (Join-Path $Directory 'state.private.json') $state
    try{
        Invoke-RpDeviceChange (Join-Path $Directory 'attachment') {
            $null=Save-DeepInventory $Directory 'before'
            Write-Host 'GREEN: connect powered DEG2 to the SAME ASUS USB4 port now. Keep it connected for 45 seconds.' -ForegroundColor Green
            Start-Sleep -Seconds 45
            $inventory=Save-DeepInventory $Directory 'after'
            $state.Observation=Get-DeepMilestone $inventory
            $state.Observation|Add-Member -NotePropertyName DisplayAnswer -NotePropertyValue (Read-Host 'Image on the RTX 4080 SUPER display? Y, N or Unknown')
        }
        $state.Phase='ObservedRequiresOfflineAnalysis'
    }catch{$state.Phase='ObservationNeedsRollback';throw}finally{
        Write-DeepJson (Join-Path $Directory 'state.private.json') $state
        Write-Warning 'Disconnect DEG2 and use Rollback for this saved run. No automatic retry is allowed.'
    }
}
function Invoke-RpRollback([string]$Directory,[string]$Decoder,[string]$Tmfs) {
    $state=Read-RpRun $Directory -ForRollback
    if(-not $state.PendingRollback){Write-Output 'Rollback already verified; no device operation.';return}
    Assert-RpDisconnected
    $owned=@(Get-RpOwnedPackages)
    if($owned.Count -gt 1){throw 'Multiple experiment packages; refuse automatic removal.'}
    if($owned.Count){
        Assert-RpOwnedPackage $owned[0] $state.InfHash $state.SysHash
        if($null -ne $state.PublishedInf -and $owned[0].Driver -ine $state.PublishedInf){throw 'Published package changed; refuse removal.'}
    }
    $state.Phase='RollbackIntent';Write-DeepJson (Join-Path $Directory 'state.private.json') $state
    $rollback=Join-Path $Directory ('rollback-'+[guid]::NewGuid().ToString('N'))
    try{
        Invoke-RpDeviceChange $rollback {
            if($owned.Count -and (Invoke-RpPnp @('/delete-driver',$owned[0].Driver,'/uninstall') (Join-Path $rollback 'delete.private.txt')) -eq 3010){throw 'Rollback removal needs reboot. Pending remains true; no further restart attempted.'}
            if((Invoke-RpPnp @('/restart-device',$state.Target) (Join-Path $rollback 'restart.private.txt')) -eq 3010){throw 'Rollback needs reboot; pending remains true.'}
            Start-Sleep -Seconds 4
        } $true
        if(@(Get-RpOwnedPackages).Count){throw 'Experiment package remains in the driver store.'}
        $driver=Get-CimInstance Win32_SystemDriver -Filter "Name='Usb4RolePolicy'"
        if($null -ne $driver -and $driver.State -eq 'Running'){throw 'Experimental driver is still running.'}
        $hostState=Get-RpHost
        if($hostState.BaseInf -ine $state.BaseInf -or @($hostState.Lower|Where-Object {$_}).Count -or @($hostState.Upper|Where-Object {$_}).Count){throw 'Original base/filter state is not restored.'}
        $state.RollbackProof=Assert-RpPolicyTrace $rollback $false $Decoder $Tmfs
        $after=Get-DeepNetworkSnapshot;Write-DeepJson (Join-Path $rollback 'network-after.private.json') $after
        $before=Get-Content -LiteralPath (Join-Path $Directory 'network-before.private.json') -Raw|ConvertFrom-Json
        Assert-RpSharing $before $after
        $state.PendingRollback=$false;$state.Phase='RollbackVerified'
    }catch{$state.Phase='RollbackUnverified';throw}finally{Write-DeepJson (Join-Path $Directory 'state.private.json') $state}
}
if($MyInvocation.InvocationName -eq '.'){return}
if($rpMode -eq 'Preview'){Write-Output 'Unsigned prototype; no installation by default. Preflight verifies Microsoft catalog, reviewed SYS hash, exact host and decoder. Install records intent then one UCSI filter/restart; Observe permits one attachment only after Microsoft startup policy proof. Rollback removes only the owned OEM extension and verifies default policy. No reboot/security/network write.';return}
switch($rpMode){
    'Preflight' {$null=Get-RpPreflight $PackageDirectory $ReviewedDriverSHA256 $SignTool $TraceFmt $TmfDirectory;Write-Output 'Preflight passed without writes or device operations.'}
    'Install' {$preflight=Get-RpPreflight $PackageDirectory $ReviewedDriverSHA256 $SignTool $TraceFmt $TmfDirectory;Invoke-RpInstall $preflight $TraceFmt $TmfDirectory}
    'Observe' {Invoke-RpObserve $RunDirectory}
    'Rollback' {Invoke-RpRollback $RunDirectory $TraceFmt $TmfDirectory}
}
