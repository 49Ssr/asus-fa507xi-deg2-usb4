#requires -Version 5.1
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$source=Join-Path $repo 'tools\analysis\Test-ParadeMcuVersion.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$fn=$ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Assert-ParadeProbeReady'},$true)
if($fn.Count -ne 1){throw 'Missing unique readiness guard.'}
. ([scriptblock]::Create($fn[0].Extent.Text))
$good=@{IsExistingNativeTestBoot=$true;ParadeCfuPackageCount=0;BoundParadeFirmwareCount=0;ConnectedDeg2Count=0;UpPhysicalNetworkCount=0;BootAgeMinutes=5}
Assert-ParadeProbeReady ([pscustomobject]$good)
$cases=@(
 @{Key='IsExistingNativeTestBoot';Value=$false},
 @{Key='ParadeCfuPackageCount';Value=1},
 @{Key='BoundParadeFirmwareCount';Value=1},
 @{Key='ConnectedDeg2Count';Value=1},
 @{Key='UpPhysicalNetworkCount';Value=1},
 @{Key='BootAgeMinutes';Value=31},
 @{Key='BootAgeMinutes';Value=-1}
)
foreach($case in $cases){
 $bad=$good.Clone();$bad[$case.Key]=$case.Value;$blocked=$false
 try{Assert-ParadeProbeReady ([pscustomobject]$bad)}catch{$blocked=$true}
 if(-not $blocked){throw ('Guard did not refuse '+$case.Key)}
}
Add-Type -Path (Join-Path $repo 'tools\analysis\ParadeVersionProbe.cs')
$blocked=$false
try{[void][ParadeVersionProbe]::ReadVersion('UNREVIEWED')}catch{$blocked=$true}
if(-not $blocked){throw 'Transport did not refuse an unreviewed endpoint.'}
'PASS: PS5 parser, seven readiness refusals, transport compiles and rejects an unknown endpoint before device access. No allowed device was opened.'
