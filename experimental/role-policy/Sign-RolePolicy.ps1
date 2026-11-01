#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Preview','Sign')][string]$Mode='Preview', [string]$BuildDirectory='',
      [string]$OutputDirectory='', [string]$SignTool='', [string]$Inf2Cat='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$signMode=$Mode
. (Join-Path $PSScriptRoot '..\..\tools\Capture-USB4DeepCompare.ps1')
if($signMode -eq 'Preview'){Write-Output 'Create a private, locally test-signed copy. Sign SYS, regenerate CAT, sign CAT, check signature math/membership, then delete the temporary current-user signing key. No root/publisher trust, boot, firmware or device changes. This cannot load in normal production signing mode.';return}
$signer=Assert-MicrosoftExecutable $SignTool 'signtool.exe'
# This exact official NuGet WDK tool has an internal-tools certificate chain.
# Pin its bytes from the separately hash-verified Microsoft WDK archive; never
# import that certificate into a trust store to make this check pass.
$catalogTool=Assert-LocalPath $Inf2Cat
if([IO.Path]::GetFileName($catalogTool) -ine 'Inf2Cat.exe' -or
   (Get-FileHash -LiteralPath $catalogTool).Hash -cne 'B594728D38B271979367ABC8060A971B8E42422738009BE126710B1F5DD0FCBC'){throw 'Use the pinned Inf2Cat from Microsoft WDK 10.0.26100.6584.'}
$build=Assert-LocalPath $BuildDirectory;Assert-DeepNoReparse $build
$manifest=Get-Content -LiteralPath (Join-Path $build 'build-manifest.json') -Raw|ConvertFrom-Json
if($manifest.Kind -ne 'Usb4RolePolicyExperimentalPackage' -or $manifest.Signing -ne 'Unsigned' -or $manifest.KernelLoaded){throw 'Use the reviewed unsigned build manifest.'}
foreach($name in @('Usb4RolePolicy.sys','Usb4RolePolicy.inf')){
    $entry=@($manifest.Files|Where-Object Name -ieq $name)
    if($entry.Count -ne 1 -or (Get-FileHash -LiteralPath (Join-Path $build ('package\'+$name))).Hash -cne $entry[0].SHA256){throw 'Build member hash mismatch.'}
}
if((Get-FileHash -LiteralPath (Join-Path $build 'package\Usb4RolePolicy.inf')).Hash -cne (Get-FileHash -LiteralPath (Join-Path $PSScriptRoot 'Usb4RolePolicy.inf')).Hash){throw 'INF no longer matches the source under review.'}
$output=Assert-LocalPath $OutputDirectory
$ownedRoot=[IO.Path]::GetFullPath((Join-Path $repo 'local\RolePolicySigning'))+'\'
if(-not $output.StartsWith($ownedRoot,[StringComparison]::OrdinalIgnoreCase) -or (Test-Path -LiteralPath $output)){throw 'Use a new private directory inside local/RolePolicySigning.'}
Assert-DeepNoReparse $repo
if(-not('Usb4RolePolicy.SignatureCheck' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'Signing.Native.cs')}
$null=[IO.Directory]::CreateDirectory($output);Assert-DeepNoReparse $output
$package=Join-Path $output 'package';$null=[IO.Directory]::CreateDirectory($package)
foreach($name in @('Usb4RolePolicy.sys','Usb4RolePolicy.inf')){[IO.File]::Copy((Join-Path $build ('package\'+$name)),(Join-Path $package $name),$false)}
$cert=$null
$state=[ordered]@{Schema=1;Kind='Usb4RolePolicyLocalTestSignature';Phase='SigningIntent';CreatedUtc=[DateTime]::UtcNow.ToString('o');CertificateThumbprint=$null;PrivateKeyRemoved=$false;RootTrustChanged=$false;PublisherTrustChanged=$false;BootChanged=$false;DriverLoaded=$false;Files=@();Error=$null}
$stateFile=Join-Path $output 'signing.private.json';Write-DeepJson $stateFile $state
try{
    $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=USB4 Role Policy Local Test '+[guid]::NewGuid().ToString('N')) -CertStoreLocation 'Cert:\CurrentUser\My' -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotBefore ([DateTime]::UtcNow.AddMinutes(-5)) -NotAfter ([DateTime]::UtcNow.AddDays(7))
    $state.CertificateThumbprint=$cert.Thumbprint;Write-DeepJson $stateFile $state
    $certificate=Join-Path $output 'LocalTest.cer';$null=Export-Certificate -Cert $cert -FilePath $certificate -Type CERT
    $sys=Join-Path $package 'Usb4RolePolicy.sys';$cat=Join-Path $package 'Usb4RolePolicy.cat'
    $before=[Usb4RolePolicy.SignatureCheck]::AuthenticodeHash($sys)
    & $signer sign /sha1 $cert.Thumbprint /s My /fd SHA256 $sys *> (Join-Path $output 'sign-sys.private.log')
    if($LASTEXITCODE -ne 0){throw 'SYS signing failed.'}
    if([Usb4RolePolicy.SignatureCheck]::AuthenticodeHash($sys) -cne $before){throw 'Signing unexpectedly changed the executable Authenticode digest.'}
    & $catalogTool ('/driver:'+$package) /os:10_GE_X64 /uselocaltime *> (Join-Path $output 'inf2cat.private.log')
    if($LASTEXITCODE -ne 0){throw 'Catalog regeneration failed.'}
    & $signer sign /sha1 $cert.Thumbprint /s My /fd SHA256 $cat *> (Join-Path $output 'sign-cat.private.log')
    if($LASTEXITCODE -ne 0){throw 'CAT signing failed.'}
    foreach($file in @($sys,$cat)){
        if((Get-AuthenticodeSignature -LiteralPath $file).SignerCertificate.Thumbprint -cne $cert.Thumbprint){throw 'Unexpected signer certificate.'}
        [Usb4RolePolicy.SignatureCheck]::VerifySignatureMath($file,$certificate)
    }
    foreach($name in @('Usb4RolePolicy.sys','Usb4RolePolicy.inf')){if(-not [Usb4RolePolicy.SignatureCheck]::CatalogContains($cat,(Join-Path $package $name))){throw 'Signed catalog member digest mismatch.'}}
    $state.Files=@(Get-ChildItem -LiteralPath $package -File|ForEach-Object{[ordered]@{Name=$_.Name;Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName).Hash}})
    $state.Phase='LocallySignedCryptographicallyVerified_NotProductionTrusted'
}catch{$state.Phase='SigningFailed';$state.Error=$_.Exception.Message;throw}finally{
    if($null -ne $cert){
        $keyPath='Cert:\CurrentUser\My\'+$cert.Thumbprint
        Remove-Item -LiteralPath $keyPath -DeleteKey -Force -ErrorAction Stop
        $state.PrivateKeyRemoved=(-not(Test-Path -LiteralPath $keyPath))
    }
    Write-DeepJson $stateFile $state
}
Write-Output ('Local test-signed package prepared; no trust/boot/device change: '+$package)
