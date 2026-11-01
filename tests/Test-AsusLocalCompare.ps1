#requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$KitDirectory)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'tools\Capture-USB4DeepCompare.ps1')
. (Join-Path $repoRoot 'tools\Capture-ASUSLocalCompare.ps1') -KitDirectory $KitDirectory
$checks=0
function Check([bool]$Condition,[string]$Why){if(-not $Condition){throw $Why};$script:checks++}
function MustThrow([scriptblock]$Code,[string]$Why){$failed=$false;try{& $Code|Out-Null}catch{$failed=$true};Check $failed $Why}
function Write-Host {param($Object,$ForegroundColor)}
function Write-Warning {param($Message)}
$fixture=Join-Path ([IO.Path]::GetTempPath()) ('AsusLocalCompare-'+[guid]::NewGuid().ToString('N'))
$script:DeepWorkRoot=Join-Path $fixture 'Owned'
$script:mockHash='b'*64;$script:mockBus='NVMe';$script:mockFree=100GB;$script:mockTarget='Asus'
$script:captures=0;$script:finishes=0;$script:stops=0;$script:contexts=0;$script:finishFails=$false
function Get-DeepMachineHash {return $script:mockHash}
function Get-DeepDrive {param($Path);return [pscustomobject]@{Bus=$script:mockBus;FileSystem='NTFS';Free=$script:mockFree}}
function Get-DeepCaptureContext {param($Which);Check ($Which -ceq 'Asus') 'Host guard explicitly selects ASUS';$script:contexts++;return [pscustomobject]@{Target=$script:mockTarget;MachineHash=$script:mockHash;MemoryBytes=32GB}}
function Invoke-DeepCapture {param($Context,$Directory)
    $script:captures++
    $status=[pscustomobject]@{Target='Asus';Result='TraceCaptured_DumpPending';Phase='DumpPending';Error=$null;ErrorDetail=$null;FinishedUtc=[DateTime]::UtcNow.ToString('o')}
    Write-DeepJson (Join-Path $Directory 'status.json') $status
    return $status
}
function Complete-DeepDumpCapture {param($Context,$Directory,$Status)
    $script:finishes++
    if($script:finishFails){throw 'mock endpoint changed'}
    $Status.Result='Captured_RequiresOfflinePolicyAndMemoryValidation';$Status.Phase='Captured'
}
function Stop-DeepOwnedTrace {param($Directory);$script:stops++}
function Export-DeepReturn {throw 'Local acquisition must never invoke USB packaging'}
function Start-ConnectionTrace {throw 'No real ETW in wrapper qualification'}
function Open-DeepTaskManager {throw 'No new snapshot/UI in wrapper qualification'}

$bundle=Read-DeepBundle $KitDirectory
$capture=Invoke-AsusLocalComparison 'Capture' $KitDirectory
Check ($script:captures -eq 1 -and $capture.Result -eq 'TraceCaptured_DumpPending') 'Capture delegates once and preserves pending result'
$record=Get-Content -LiteralPath (Join-Path $capture.Run 'run.private.json') -Raw|ConvertFrom-Json
Check ($record.Target -ceq 'Asus' -and $record.LocalOnly -eq $true -and $null -eq $record.Transport) 'Local run records ASUS, local-only and no transport'
Check ($record.BundleId -ceq $bundle.BundleId -and $record.MachineHash -ceq $script:mockHash) 'Run binds exact source kit and Windows identity'
Check ((Get-FileHash (Join-Path $capture.Run 'bundle-manifest.json')).Hash -ceq (Get-FileHash (Join-Path $KitDirectory 'bundle-manifest.json')).Hash) 'Source manifest copied unchanged'
Check (Test-Path -LiteralPath (Join-Path $capture.Run 'local-acquisition-source.ps1')) 'Local entry-point source retained with capture'
$latest=Join-Path $script:DeepWorkRoot 'asus-local-latest.private.json'
Check ((Get-Content -LiteralPath $latest -Raw|ConvertFrom-Json).Run -ceq $capture.Run) 'Durable latest-run link saved before acquisition'
$beforeLink=(Get-FileHash $latest).Hash
$script:mockFree=1GB;MustThrow {Invoke-AsusLocalComparison 'Capture' $KitDirectory} 'Insufficient SSD space refuses before capture';$script:mockFree=100GB
$script:mockTarget='Dell';MustThrow {Invoke-AsusLocalComparison 'Capture' $KitDirectory} 'Wrong context cannot become ASUS run';$script:mockTarget='Asus'
$script:mockBus='USB';MustThrow {Invoke-AsusLocalComparison 'Capture' $KitDirectory} 'USB source refused for local entry point';$script:mockBus='NVMe'
Check ($script:captures -eq 1 -and (Get-FileHash $latest).Hash -ceq $beforeLink) 'Failed preflights preserve previous latest run without acquisition'
$finished=Invoke-AsusLocalComparison 'FinishDump' $KitDirectory
Check ($finished.Run -ceq $capture.Run -and $finished.Result -eq 'Captured_RequiresOfflinePolicyAndMemoryValidation') 'Finish resumes the pending run in place'
Check ($script:captures -eq 1 -and $script:finishes -eq 1 -and $script:stops -eq 1) 'Resume cleans only owned trace and never recaptures'
Check ((Get-Content -LiteralPath (Join-Path $capture.Run 'status.json') -Raw|ConvertFrom-Json).Result -ceq $finished.Result) 'Resumed status persisted'
MustThrow {Assert-AsusLocalRecord $capture.Run ('0'*32)} 'Mismatched source kit refuses resumed run'
$script:mockHash='c'*64;MustThrow {Assert-AsusLocalRecord $capture.Run $bundle.BundleId} 'Another Windows identity refuses resume';$script:mockHash='b'*64
$record.LocalOnly=$false;Write-DeepJson (Join-Path $capture.Run 'run.private.json') $record
MustThrow {Assert-AsusLocalRecord $capture.Run $bundle.BundleId} 'USB-bound record cannot be silently converted to local'
$record.LocalOnly=$true;$record.Target='Dell';Write-DeepJson (Join-Path $capture.Run 'run.private.json') $record
MustThrow {Assert-AsusLocalRecord $capture.Run $bundle.BundleId} 'Dell record cannot resume through ASUS entry point'
$record.Target='Asus';Write-DeepJson (Join-Path $capture.Run 'run.private.json') $record
MustThrow {Assert-AsusLocalRecord $fixture $bundle.BundleId} 'Outside owned Runs directory refused'
$beforeContexts=$script:contexts;$stop=Invoke-AsusLocalComparison 'StopTrace' $KitDirectory
Check ($stop.Run -ceq $capture.Run -and $script:contexts -eq $beforeContexts) 'Owned cleanup does not depend on a fresh hardware inventory'
$second=Invoke-AsusLocalComparison 'Capture' $KitDirectory
Check ($second.Run -cne $capture.Run -and (Test-Path (Join-Path $capture.Run 'status.json'))) 'Fresh run preserves earlier evidence'
$script:finishFails=$true;$failed=Invoke-AsusLocalComparison 'FinishDump' $KitDirectory
$saved=Get-Content -LiteralPath (Join-Path $second.Run 'status.json') -Raw|ConvertFrom-Json
Check ($saved.Error -eq 'mock endpoint changed' -and $saved.Result -eq 'TraceCaptured_DumpPending') 'Completion failure records error without inventing success'
Check ($script:captures -eq 2) 'Failure and resume never trigger another attachment capture'
Write-Output ('ASUS local entry-point validation passed: '+$checks+' checks. ETW, snapshot and hardware context mocked; actual files, hashes and source-kit verification exercised.')
