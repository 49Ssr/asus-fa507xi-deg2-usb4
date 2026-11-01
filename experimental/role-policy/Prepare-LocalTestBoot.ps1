#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Preview','Snapshot','Prepare','Restore','Verify')][string]$Mode='Preview',
      [string]$SigningRecord='', [string]$StateFile='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$bootMode=$Mode
. (Join-Path $PSScriptRoot '..\..\tools\Capture-USB4DeepCompare.ps1')
function Invoke-PolicyBcd([string[]]$Arguments){
    $text=& (Join-Path $env:SystemRoot 'System32\bcdedit.exe') @Arguments 2>&1
    if($LASTEXITCODE -ne 0){throw ('BCD operation failed: '+($text -join ' '))}
    return ($text -join [Environment]::NewLine)
}
function Get-PolicyCurrentBoot {
    $text=Invoke-PolicyBcd @('/enum','{current}','/v')
    $match=[regex]::Match($text,'\{[0-9a-fA-F-]{36}\}')
    if(-not $match.Success){throw 'Current Windows loader identity unavailable.'}
    return $match.Value.ToLowerInvariant()
}
function Get-PolicySecurity {
    if(-not('Usb4RolePolicy.SignatureCheck' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'Signing.Native.cs')}
    $flags=[Usb4RolePolicy.SignatureCheck]::CodeIntegrityFlags()
    return [pscustomobject]@{SecureBoot=[bool](Confirm-SecureBootUEFI);TestSigning=[bool]($flags-band 2);Hvci=[bool]($flags-band 0x400);Flags=$flags}
}
function Assert-PolicyAdmin {
    $p=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if(-not [Environment]::Is64BitProcess -or $PSVersionTable.PSVersion.Major -ne 5 -or -not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Use 64-bit Administrator Windows PowerShell 5.1.'}
}
function Assert-PolicyNoOldOverrides {
    $path='HKLM:\SYSTEM\CurrentControlSet\Services\Usb4HostRouter\Parameters'
    if(Test-Path -LiteralPath $path){
        $properties=Get-ItemProperty -LiteralPath $path -ErrorAction Stop
        foreach($name in @('EnableUSB4v2Support','UserControlOfIdleSettings')){
            if($null -ne $properties.PSObject.Properties[$name]){throw ('Retired test-gated override remains present: '+$name+'. Review its restoration; do not activate it accidentally.')}
        }
    }
}
function Test-PolicyTrust([string]$Store,[string]$Thumbprint){return Test-Path ('Cert:\LocalMachine\'+$Store+'\'+$Thumbprint)}
function Add-PolicyTrust([string]$Store,[string]$Certificate){$null=Import-Certificate -FilePath $Certificate -CertStoreLocation ('Cert:\LocalMachine\'+$Store)}
function Remove-PolicyTrust([string]$Store,[string]$Thumbprint){Remove-Item -LiteralPath ('Cert:\LocalMachine\'+$Store+'\'+$Thumbprint) -Force}
function Invoke-LocalTestBoot([string]$Action,[string]$SigningRecord,[string]$StateFile){
$bootMode=$Action
Assert-PolicyAdmin
if($bootMode -in @('Snapshot','Prepare')){Assert-PolicyNoOldOverrides}
$statePath=Assert-LocalPath $StateFile
$prefix=[IO.Path]::GetFullPath((Join-Path $repo 'local\RolePolicySigning'))+'\'
if(-not $statePath.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Keep the boot record inside private local/RolePolicySigning.'}
Assert-DeepNoReparse (Split-Path $statePath -Parent)
if($bootMode -eq 'Snapshot'){
    if(Test-Path -LiteralPath $statePath){throw 'Snapshot refuses an existing record.'}
    $context=Get-DeepCaptureContext 'Asus';$security=Get-PolicySecurity
    if(-not $security.SecureBoot -or $security.TestSigning -or -not $security.Hvci){throw 'Snapshot requires original Secure Boot on, test signing off and HVCI running.'}
    $recordPath=Assert-LocalPath $SigningRecord;Assert-DeepNoReparse $recordPath
    $signed=Get-Content -LiteralPath $recordPath -Raw|ConvertFrom-Json
    if($signed.Kind -ne 'Usb4RolePolicyLocalTestSignature' -or $signed.Phase -ne 'LocallySignedCryptographicallyVerified_NotProductionTrusted' -or -not $signed.PrivateKeyRemoved){throw 'Reviewed local signing record is required.'}
    $certPath=Join-Path (Split-Path $recordPath -Parent) 'LocalTest.cer'
    $cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2($certPath)
    try{if($cert.Thumbprint -cne $signed.CertificateThumbprint -or [DateTime]::UtcNow -lt $cert.NotBefore.ToUniversalTime() -or [DateTime]::UtcNow -gt $cert.NotAfter.ToUniversalTime()){throw 'Public certificate changed or is outside its validity period.'}}finally{$cert.Dispose()}
    $state=[ordered]@{Schema=1;Kind='Usb4RolePolicyTestBoot';MachineHash=$context.MachineHash;OriginalBoot=(Get-PolicyCurrentBoot);OriginalSecurity=$security;OriginalBootManager=(Invoke-PolicyBcd @('/enum','{bootmgr}','/v'));SigningRecord=$recordPath;SigningRecordSHA256=(Get-FileHash -LiteralPath $recordPath).Hash;Certificate=$certPath;CertificateSHA256=(Get-FileHash -LiteralPath $certPath).Hash;CertificateThumbprint=$signed.CertificateThumbprint;RootWasPresent=(Test-PolicyTrust 'Root' $signed.CertificateThumbprint);PublisherWasPresent=(Test-PolicyTrust 'TrustedPublisher' $signed.CertificateThumbprint);Label=('USB4 role-policy test '+[guid]::NewGuid().ToString('N'));TestEntry=$null;Phase='SnapshotOnly';CreatedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-DeepJson $statePath $state
    Write-Output 'Original state saved. No boot/trust change. Review the approved firmware/recovery procedure before Prepare.'
    return
}
$state=Get-Content -LiteralPath $statePath -Raw|ConvertFrom-Json
if($state.Kind -ne 'Usb4RolePolicyTestBoot' -or $state.Schema -ne 1 -or $state.MachineHash -cne (Get-DeepMachineHash) -or $state.CertificateThumbprint -notmatch '^[A-F0-9]{40}$'){throw 'Boot record belongs to another machine or has an invalid certificate identity.'}
if($bootMode -eq 'Prepare'){
    if($state.Phase -ne 'SnapshotOnly' -or $null -ne $state.TestEntry){throw 'Prepare is one-shot; review/restore an interrupted record first.'}
    if((Get-PolicyCurrentBoot) -cne $state.OriginalBoot){throw 'Prepare must run from the original analysed Windows loader.'}
    $security=Get-PolicySecurity
    if($security.SecureBoot -or $security.TestSigning -or -not $security.Hvci){throw 'Owner-approved manual Secure Boot off and unchanged running HVCI are required. This script does not change either.'}
    if((Get-FileHash -LiteralPath $state.SigningRecord).Hash -cne $state.SigningRecordSHA256 -or (Get-FileHash -LiteralPath $state.Certificate).Hash -cne $state.CertificateSHA256){throw 'Reviewed signing material changed.'}
    if((Read-Host 'This creates one temporary test boot and trusts its exact public certificate. Type PREPARE') -cne 'PREPARE'){throw 'Preparation not confirmed.'}
    $state.Phase='CopyIntent';Write-DeepJson $statePath $state
    $reply=Invoke-PolicyBcd @('/copy',$state.OriginalBoot,'/d',$state.Label)
    $match=[regex]::Match($reply,'\{[0-9a-fA-F-]{36}\}')
    if(-not $match.Success){throw 'Copy reply lacks an owned entry ID. Restore can discover the unique saved label; do not copy again.'}
    $newId=$match.Value.ToLowerInvariant()
    if($newId -ceq $state.OriginalBoot){throw 'Copy reply points to the original loader; refuse any test-signing write.'}
    $clone=Invoke-PolicyBcd @('/enum',$newId,'/v')
    if([regex]::Match($clone,'\{[0-9a-fA-F-]{36}\}').Value -ine $newId -or -not $clone.Contains($state.Label)){throw 'New loader ownership did not verify; do not enable test signing.'}
    $state.TestEntry=$newId;$state.Phase='EntryCreated';Write-DeepJson $statePath $state
    $null=Invoke-PolicyBcd @('/set',$state.TestEntry,'testsigning','on')
    if(-not $state.RootWasPresent){Add-PolicyTrust 'Root' $state.Certificate}
    if(-not $state.PublisherWasPresent){Add-PolicyTrust 'TrustedPublisher' $state.Certificate}
    $state.Phase='Prepared';Write-DeepJson $statePath $state
    Write-Output ('Prepared ONE test loader: '+$state.TestEntry+'. Original default was not changed. Select this named entry manually; no automatic restart.')
    return
}
if($bootMode -eq 'Restore'){
    $owned=@(Get-WindowsDriver -Online -All|Where-Object {[IO.Path]::GetFileName([string]$_.OriginalFileName) -ieq 'Usb4RolePolicy.inf'})
    $driver=Get-CimInstance Win32_SystemDriver -Filter "Name='Usb4RolePolicy'"
    if($owned.Count -or ($null -ne $driver -and $driver.State -eq 'Running')){throw 'Remove the experiment package with its saved-run Rollback before restoring signing trust.'}
    if($null -eq $state.TestEntry -and $state.Phase -eq 'CopyIntent'){
        $all=Invoke-PolicyBcd @('/enum','osloader','/v')
        $blocks=@([regex]::Split($all,'(?:\r?\n){2,}')|Where-Object { $_.Contains($state.Label) })
        if($blocks.Count -gt 1){throw 'Cannot uniquely recover the interrupted copy. Review the saved label; no entry will be deleted.'}
        if($blocks.Count){
            $id=[regex]::Match($blocks[0],'\{[0-9a-fA-F-]{36}\}')
            if(-not $id.Success){throw 'Interrupted entry identity unavailable.'}
            $state.TestEntry=$id.Value.ToLowerInvariant();Write-DeepJson $statePath $state
        }
    }
    if($null -ne $state.TestEntry){
        if($state.TestEntry -cne $state.OriginalBoot -and $state.TestEntry -match '^\{[0-9a-f-]{36}\}$'){
            $inventory=Invoke-PolicyBcd @('/enum','all','/v')
            $blocks=@([regex]::Split($inventory,'(?:\r?\n){2,}')|Where-Object {
                [regex]::Match($_,'\{[0-9a-fA-F-]{36}\}').Value -ieq $state.TestEntry
            })
            if($blocks.Count -gt 1){throw 'Boot-entry identity is ambiguous.'}
            if($blocks.Count){
                if(-not $blocks[0].Contains($state.Label)){throw 'Owned boot-entry description changed. Refuse deletion.'}
                $state.Phase='EntryDeleteIntent';Write-DeepJson $statePath $state
                $null=Invoke-PolicyBcd @('/delete',$state.TestEntry)
            }
            $state.TestEntry=$null;Write-DeepJson $statePath $state
        }else{throw 'Unsafe boot-entry identity.'}
    }
    foreach($store in @('Root','TrustedPublisher')){
        $wasPresent=if($store -eq 'Root'){$state.RootWasPresent}else{$state.PublisherWasPresent}
        if(-not $wasPresent -and (Test-PolicyTrust $store $state.CertificateThumbprint)){Remove-PolicyTrust $store $state.CertificateThumbprint}
    }
    $state.Phase='EntryAndTrustRemoved_FirmwareRestorePending';Write-DeepJson $statePath $state
    Write-Output 'Owned test entry/trust removed. Manually restore Secure Boot and boot the original Windows entry, then run Verify.'
    return
}
if($bootMode -eq 'Verify'){
    $security=Get-PolicySecurity
    if($state.Phase -ne 'EntryAndTrustRemoved_FirmwareRestorePending' -or (Get-PolicyCurrentBoot) -cne $state.OriginalBoot -or
       -not $security.SecureBoot -or $security.TestSigning -or -not $security.Hvci){throw 'Original normal boot/security restoration is not yet verified.'}
    if((Invoke-PolicyBcd @('/enum','{bootmgr}','/v')) -cne $state.OriginalBootManager){throw 'Boot-manager state differs; inspect the snapshot instead of rewriting it.'}
    foreach($store in @('Root','TrustedPublisher')){
        $expected=if($store -eq 'Root'){$state.RootWasPresent}else{$state.PublisherWasPresent}
        if((Test-PolicyTrust $store $state.CertificateThumbprint) -ne $expected){throw 'Certificate trust restoration differs from snapshot.'}
    }
    $state.Phase='OriginalSecurityVerified';Write-DeepJson $statePath $state
    Write-Output 'Original loader, Secure Boot, HVCI, test-signing state, boot manager and exact certificate trust verified.'
}
}
if($MyInvocation.InvocationName -eq '.'){return}
if($bootMode -eq 'Preview'){Write-Output 'Snapshot saves the original boot/security state only. Prepare, after owner-approved manual Secure Boot off, creates ONE test loader entry and trusts ONLY the generated public certificate. No auto reboot, firmware toggle, Memory Integrity change or driver install. Restore removes only owned entry/trust; Verify requires original normal boot/security back.';return}
Invoke-LocalTestBoot $bootMode $SigningRecord $StateFile
