#requires -Version 5.1
<# Read installed device bindings and copy matching signed System driver packages
   into ignored local storage. Does not install/uninstall anything. #>
[CmdletBinding()]
param([switch]$Preview)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'NativeBoot.Common.ps1')
Assert-ASUSModel
$repo=Split-Path -Parent $PSScriptRoot
$out=Join-Path $repo 'local\Drivers'
Assert-NoReparseAncestor $out
if((Test-Path -LiteralPath (Join-Path $out 'manifest.json')) -and -not $Preview){throw 'A baseline already exists. It will not be overwritten.'}
$raw=& (Join-Path $env:SystemRoot 'System32\pnputil.exe') /enum-devices /connected /services /properties /format xml
if($LASTEXITCODE -ne 0){throw 'Installed-device inventory failed.'}
[xml]$xml=$raw -join [Environment]::NewLine
$specs=@(
    @{Pattern='^ACPI\\AMDI0010\\';Original='amdi2c.inf';RequiredVersion=''}
    @{Pattern='^ACPI\\AMDI0030\\';Original='amdgpio2.inf';RequiredVersion=''}
    @{Pattern='^ACPI\\AMDI0009\\';Original='AmdMicroPEP.inf';RequiredVersion=''}
    @{Pattern='^ACPI\\AMDI0052\\';Original='amdppmpf.inf';RequiredVersion=''}
    @{Pattern='^ACPI\\ASUS2018\\';Original='asussci2.inf';RequiredVersion=''}
    @{Pattern='^ACPI\\PS88300A\\';Original='prspbdrv.inf';RequiredVersion='1.0.8.0'}
    @{Pattern='^ACPI\\PS883008\\';Original='prhiddrv.inf';RequiredVersion='1.0.11.0'}
)
$resolved=@(foreach($spec in $specs){
    $device=$xml.SelectNodes('//Device')|Where-Object {$_.GetAttribute('InstanceId') -match $spec.Pattern}|Select-Object -First 1
    if(-not $device){throw ('Required baseline device is absent: '+$spec.Original)}
    $driverNode=$device.SelectSingleNode('DriverName')
    if($null -eq $driverNode -or $driverNode.InnerText -notmatch '^oem\d+\.inf$'){throw 'An installed third-party driver binding is required.'}
    $published=$driverNode.InnerText
    $infHash=(Get-FileHash -LiteralPath (Join-Path $env:SystemRoot ('INF\'+$published)) -Algorithm SHA256).Hash
    $matches=@(Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'System32\DriverStore\FileRepository') -Directory -Filter ($spec.Original+'_amd64_*')|Where-Object {
        $candidate=Join-Path $_.FullName $spec.Original
        (Test-Path -LiteralPath $candidate) -and (Get-FileHash -LiteralPath $candidate -Algorithm SHA256).Hash -eq $infHash
    })
    if($matches.Count -ne 1){throw ('Could not uniquely resolve installed package '+$spec.Original)}
    $package=$matches[0]
    Assert-NoReparseAncestor $package.FullName
    $inf=Join-Path $package.FullName $spec.Original
    $text=Get-Content -LiteralPath $inf -Raw
    if($text -notmatch '(?im)^\s*Class\s*=\s*System\s*$'){throw 'Firmware and other non-System packages are excluded.'}
    $versionNode=$device.SelectSingleNode('Properties/Property[@Key="DEVPKEY_Device_DriverVersion"]/Value')
    $version=if($null -ne $versionNode){$versionNode.InnerText}else{''}
    if($spec.RequiredVersion -and $version -ne $spec.RequiredVersion){throw ('Restore the original Parade baseline first; '+$spec.Original+' is '+$version)}
    $cats=@(Get-ChildItem -LiteralPath $package.FullName -File -Filter '*.cat')
    if($cats.Count -ne 1 -or (Get-AuthenticodeSignature -LiteralPath $cats[0].FullName).Status -ne 'Valid'){throw 'Catalog signature is not valid.'}
    [pscustomobject]@{Source=$package.FullName;Directory=$package.Name;Original=$spec.Original;Published=$published;Version=$version;Hash=$infHash}
})
if($Preview){$resolved|Select-Object Original,Version,Directory|Format-Table -AutoSize;exit 0}
New-Item -ItemType Directory -Path $out -Force|Out-Null
$packages=@(foreach($record in $resolved){
    $target=Join-Path $out $record.Directory
    if(Test-Path -LiteralPath $target){throw 'A destination package already exists; refusing overwrite.'}
    Copy-Item -LiteralPath $record.Source -Destination $target -Recurse
    $files=@(Get-ChildItem -LiteralPath $target -Recurse -File|ForEach-Object {
        [pscustomobject]@{Path=$_.FullName.Substring($out.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash;Bytes=$_.Length}
    })
    [pscustomobject]@{Inf=(Join-Path $record.Directory $record.Original);DriverVersion=$record.Version;Class='System';PublishedBaseline=$record.Published;InfSHA256=$record.Hash;Files=$files}
})
[pscustomobject]@{Schema=1;Model='FA507XI';Purpose='Signed installed baseline System packages only; no Firmware-class package';Packages=$packages}|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $out 'manifest.json') -Encoding UTF8
Write-Host ('Copied seven baseline packages into '+$out+'. No driver installed or changed.')
