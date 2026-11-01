#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Preview','Build')][string]$Mode='Preview',
      [string]$CompilerRoot='', [string]$WdkRoot='', [string]$SdkRoot='', [string]$OutputDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Mode -eq 'Preview'){Write-Output 'Compile/test the shared policy parser and build an unsigned x64 KMDF 1.15 filter plus catalog. No install, signing, device restart or setting change.';return}
foreach($path in @($CompilerRoot,$WdkRoot,$SdkRoot,$OutputDirectory)){
    if([string]::IsNullOrWhiteSpace($path) -or $path.StartsWith('\\') -or $path -match '["\r\n]'){throw 'Supply explicit local toolchain/output paths.'}
}
$out=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $out){throw 'Build refuses an existing output directory.'}
$cl=Join-Path $CompilerRoot 'bin\Hostx64\x64\cl.exe'
$link=Join-Path $CompilerRoot 'bin\Hostx64\x64\link.exe'
$version='10.0.26100.0'
$includes=@((Join-Path $CompilerRoot 'include'),(Join-Path $WdkRoot ('Include\'+$version+'\km')),
    (Join-Path $WdkRoot ('Include\'+$version+'\shared')),(Join-Path $WdkRoot 'Include\wdf\kmdf\1.15'),
    (Join-Path $SdkRoot ('Include\'+$version+'\ucrt')),(Join-Path $SdkRoot ('Include\'+$version+'\shared')),
    (Join-Path $SdkRoot ('Include\'+$version+'\um')))
foreach($path in @($cl,$link)+$includes){if(-not(Test-Path -LiteralPath $path)){throw ('Missing toolchain input: '+$path)}}
$null=[IO.Directory]::CreateDirectory($out)
$flags=@('/nologo','/W4','/WX','/utf-8','/D_AMD64_','/D_WIN64','/D_WIN32_WINNT=0x0A00')
foreach($path in $includes){$flags+=('/I'+$path)}
$userLibraries=@(('/LIBPATH:'+(Join-Path $CompilerRoot 'lib\x64')),
    ('/LIBPATH:'+(Join-Path $SdkRoot ('Lib\'+$version+'\ucrt\x64'))),
    ('/LIBPATH:'+(Join-Path $SdkRoot ('Lib\'+$version+'\um\x64'))))
Push-Location $out
try{
    & $cl @flags /MT /O2 /TC (Join-Path $PSScriptRoot 'Policy.c') (Join-Path $PSScriptRoot 'TestPolicy.c') /Fe:TestPolicy.exe /link @userLibraries *> native-tests-build.log
    if($LASTEXITCODE -ne 0){throw 'Native core test compilation failed; read native-tests-build.log.'}
    & (Join-Path $out 'TestPolicy.exe') | Tee-Object -FilePath native-tests-result.txt
    if($LASTEXITCODE -ne 0){throw 'Native core test failed.'}
    $kernelFlags=$flags+@('/kernel','/DNTDDI_VERSION=0x0A000000','/Zl','/GS','/O2','/Gy','/Z7','/c')
    & $cl @kernelFlags (Join-Path $PSScriptRoot 'Driver.c') (Join-Path $PSScriptRoot 'Policy.c') *> driver-build.log
    if($LASTEXITCODE -ne 0){throw 'Kernel compilation failed; read driver-build.log.'}
    $kernelLibraries=@(('/LIBPATH:'+(Join-Path $WdkRoot ('Lib\'+$version+'\km\x64'))),
        ('/LIBPATH:'+(Join-Path $WdkRoot 'Lib\wdf\kmdf\x64\1.15')))
    $package=Join-Path $out 'package';$null=[IO.Directory]::CreateDirectory($package)
    & $link /nologo /driver /subsystem:native /entry:FxDriverEntry /nodefaultlib /machine:x64 /integritycheck /dynamicbase /nxcompat /debug:full /pdb:Usb4RolePolicy.pdb /pdbaltpath:Usb4RolePolicy.pdb /out:package\Usb4RolePolicy.sys Driver.obj Policy.obj @kernelLibraries ntoskrnl.lib hal.lib BufferOverflowFastFailK.lib WdfDriverEntry.lib WdfLdr.lib *> driver-link.log
    if($LASTEXITCODE -ne 0){throw 'Kernel link failed; read driver-link.log.'}
    [IO.File]::Copy((Join-Path $PSScriptRoot 'Usb4RolePolicy.inf'),(Join-Path $package 'Usb4RolePolicy.inf'),$false)
    $infverif=Join-Path $WdkRoot ('tools\'+$version+'\x64\InfVerif.exe')
    & $infverif /w /v (Join-Path $package 'Usb4RolePolicy.inf') *> infverif.log
    if($LASTEXITCODE -ne 0){throw 'INF verification failed; read infverif.log.'}
    $inf2cat=Join-Path $WdkRoot ('bin\'+$version+'\x86\Inf2Cat.exe')
    & $inf2cat ('/driver:'+$package) /os:10_GE_X64 /uselocaltime *> inf2cat.log
    if($LASTEXITCODE -ne 0){throw 'Catalog generation failed; read inf2cat.log.'}
    $files=@(Get-ChildItem -LiteralPath $package -File|ForEach-Object {@{Name=$_.Name;Bytes=$_.Length;SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
    $manifest=@{Schema=1;Kind='Usb4RolePolicyExperimentalPackage';Signing='Unsigned';KernelLoaded=$false;HardwareQualified=$false;KMDF='1.15';Wdk='26100';CreatedUtc=[DateTime]::UtcNow.ToString('o');Files=$files}
    [IO.File]::WriteAllText((Join-Path $out 'build-manifest.json'),($manifest|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
    Write-Output ('Unsigned experimental package built: '+$package)
}finally{Pop-Location}
