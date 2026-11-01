#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Preview','Build')][string]$Mode='Preview',[string]$OutputDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Mode -eq 'Preview'){
    Write-Output 'Build a nine-source-file USB4 deep-comparison kit with SHA-256 manifest. No third-party binaries or symbols are bundled. Output must be a new local directory.'
    exit 0
}
if([string]::IsNullOrWhiteSpace($OutputDirectory) -or $OutputDirectory.StartsWith('\\')){throw 'Supply a new local output directory.'}
$output=[IO.Path]::GetFullPath($OutputDirectory)
if(Test-Path -LiteralPath $output){throw 'Build refuses to overwrite an existing output directory.'}
$map=[ordered]@{
    'Capture-USB4DeepCompare.ps1'='Capture-USB4DeepCompare.ps1'
    'Usb4Capture.Common.ps1'='Usb4Capture.Common.ps1'
    'deep-compare\DeepCapture.Native.cs'='deep-compare\DeepCapture.Native.cs'
    'START-DELL.cmd'='deep-compare\START-DELL.cmd'
    'START-ASUS.cmd'='deep-compare\START-ASUS.cmd'
    'FINISH-DUMP.cmd'='deep-compare\FINISH-DUMP.cmd'
    'RETURN.cmd'='deep-compare\RETURN.cmd'
    'STOP-TRACE.cmd'='deep-compare\STOP-TRACE.cmd'
    'README.txt'='deep-compare\README.txt'
}
foreach($source in $map.Values){if(-not(Test-Path -LiteralPath (Join-Path $PSScriptRoot $source) -PathType Leaf)){throw ('Source missing: '+$source)}}
$ancestor=[IO.Path]::GetDirectoryName($output)
while(-not(Test-Path -LiteralPath $ancestor)){$ancestor=[IO.Path]::GetDirectoryName($ancestor)}
$item=Get-Item -LiteralPath $ancestor
while($null -ne $item){if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'Reparse output ancestor refused.'};$item=$item.Parent}
$null=New-Item -ItemType Directory -Path $output -Force
$files=@(foreach($name in $map.Keys){
    $source=Join-Path $PSScriptRoot $map[$name];$dest=Join-Path $output $name
    $null=New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force
    if($name.EndsWith('.cmd')){$text=[IO.File]::ReadAllText($source).Replace("`r`n","`n").Replace("`n","`r`n");[IO.File]::WriteAllText($dest,$text,[Text.Encoding]::ASCII)}
    else{[IO.File]::Copy($source,$dest,$false)}
    [ordered]@{Path=$name;Bytes=(Get-Item -LiteralPath $dest).Length;SHA256=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash}
})
$manifest=[ordered]@{Schema=1;Kind='USB4DeepCompare';Revision='2026-11-01-resumable-dump-handoff';BundleId=[guid]::NewGuid().ToString('N');CreatedUtc=[DateTime]::UtcNow.ToString('o');Files=$files;ThirdPartyBinariesIncluded=$false;DefaultEntryPoint='START-DELL.cmd';HardwareCaptureQualified=$false}
[IO.File]::WriteAllText((Join-Path $output 'bundle-manifest.json'),($manifest|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
Write-Output ('Built verified-source manifest: '+$output)
