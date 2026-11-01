#requires -Version 5.1
<# Local-only entry point for the exercised passive matched collector.
   No USB transport, firmware command, helper driver or setting change. #>
[CmdletBinding()]
param([ValidateSet('Preview','Capture','FinishDump','StopTrace')][string]$Mode='Preview',
      [string]$KitDirectory='', [string]$RunDirectory='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$asusLocalMode=$Mode;$asusLocalKit=$KitDirectory;$asusLocalRun=$RunDirectory
if([string]::IsNullOrWhiteSpace($asusLocalKit)){$asusLocalKit=Join-Path $PSScriptRoot 'USB4-Deep-Compare-resumable'}
$script:AsusLocalSource=$PSCommandPath

function Assert-AsusLocalRecord([string]$Directory,[string]$BundleId) {
    $record=Assert-DeepRun $Directory
    if($record.Target -cne 'Asus' -or $record.BundleId -cne $BundleId -or
       $null -eq $record.PSObject.Properties['LocalOnly'] -or $record.LocalOnly -ne $true){throw 'This is not an ASUS local capture from this verified kit.'}
    return $record
}
function Invoke-AsusLocalComparison([string]$Operation,[string]$Kit,[string]$SelectedRun='') {
    $bundle=Read-DeepBundle $Kit
    $drive=Get-DeepDrive $Kit
    if($drive.Bus -eq 'USB' -or $drive.FileSystem -ne 'NTFS'){throw 'This entry point requires the source kit on local NTFS storage.'}
    $latest=Join-Path $script:DeepWorkRoot 'asus-local-latest.private.json'
    if($Operation -eq 'Capture'){
        $context=Get-DeepCaptureContext 'Asus'
        if($context.Target -cne 'Asus'){throw 'ASUS context required.'}
        $storage=Get-DeepDrive $script:DeepWorkRoot
        if($storage.Bus -eq 'USB' -or $storage.FileSystem -ne 'NTFS' -or $storage.Free -lt ($context.MemoryBytes+4GB)){throw 'Capture requires internal NTFS with physical-RAM size plus 4 GiB free.'}
        $ancestor=$script:DeepWorkRoot
        while(-not(Test-Path -LiteralPath $ancestor)){$ancestor=[IO.Path]::GetDirectoryName($ancestor)}
        Assert-DeepNoReparse $ancestor
        $SelectedRun=Join-Path $script:DeepWorkRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-Asus-local-'+[guid]::NewGuid().ToString('N').Substring(0,8))
        $null=New-Item -ItemType Directory -Path $SelectedRun -Force;Assert-DeepNoReparse $SelectedRun
        $record=[ordered]@{Schema=1;Kind='USB4DeepCompareRun';Run=$SelectedRun;Target='Asus';MachineHash=$context.MachineHash;BundleId=$bundle.BundleId;Transport=$null;LocalOnly=$true;StartedUtc=[DateTime]::UtcNow.ToString('o')}
        Write-DeepJson (Join-Path $SelectedRun 'run.private.json') $record
        [IO.File]::Copy((Join-Path $Kit 'bundle-manifest.json'),(Join-Path $SelectedRun 'bundle-manifest.json'),$false)
        [IO.File]::Copy($script:AsusLocalSource,(Join-Path $SelectedRun 'local-acquisition-source.ps1'),$false)
        Write-DeepJson $latest $record
        Write-Host 'If Task Manager is already open, close its window before continuing. It will reopen for the full snapshot after tracing.'
        $result=Invoke-DeepCapture $context $SelectedRun
    }else{
        if([string]::IsNullOrWhiteSpace($SelectedRun)){
            $link=Get-Content -LiteralPath $latest -Raw|ConvertFrom-Json
            $SelectedRun=[string]$link.Run
        }
        $null=Assert-AsusLocalRecord $SelectedRun $bundle.BundleId
        Stop-DeepOwnedTrace $SelectedRun
        if($Operation -eq 'StopTrace'){return [pscustomobject]@{Run=$SelectedRun;Result='OwnedTraceCleanupRequested'}}
        $context=Get-DeepCaptureContext 'Asus'
        $result=Get-Content -LiteralPath (Join-Path $SelectedRun 'status.json') -Raw|ConvertFrom-Json
        if($result.Target -cne 'Asus'){throw 'Saved status is not an ASUS capture.'}
        try{Complete-DeepDumpCapture $context $SelectedRun $result}
        catch{$result.Error=$_.Exception.Message;$result.ErrorDetail=@{Phase=$result.Phase;Id=$_.FullyQualifiedErrorId;Stack=$_.ScriptStackTrace};Write-Warning $result.Error}
        finally{$result.FinishedUtc=[DateTime]::UtcNow.ToString('o');Write-DeepJson (Join-Path $SelectedRun 'status.json') $result}
    }
    Write-Host ('ASUS result: '+$result.Result+'; local evidence: '+$SelectedRun) -ForegroundColor Cyan
    Write-Host 'No USB copy or compression is needed. Keep the full dump in its current location for offline comparison.'
    if($result.Result -eq 'TraceCaptured_DumpPending'){Write-Host 'For THIS local run use FINISH-ASUS-LOCAL.cmd beside START-ASUS-LOCAL.cmd. Do not start another connection capture.'}
    return [pscustomobject]@{Run=$SelectedRun;Result=$result.Result}
}
if($MyInvocation.InvocationName -eq '.'){return}
if($asusLocalMode -eq 'Preview'){
    Write-Output 'ASUS FA507XI only: verified source kit, internal-NTFS evidence, existing passive handshake collector, native Task Manager full dump, same-run completion. No USB return, network configuration or firmware operation.'
    return
}
try{
    $asusLocalKit=[IO.Path]::GetFullPath($asusLocalKit)
    if($asusLocalKit.StartsWith('\\') -or -not(Test-Path -LiteralPath (Join-Path $asusLocalKit 'Capture-USB4DeepCompare.ps1') -PathType Leaf)){throw 'Select the verified local deep-comparison source kit.'}
    # Keep the imported functions in this script scope; its USB entry point is skipped.
    . (Join-Path $asusLocalKit 'Capture-USB4DeepCompare.ps1') -Mode Preview -Target Asus
    $asusLocalResult=Invoke-AsusLocalComparison $asusLocalMode $asusLocalKit $asusLocalRun
    $asusLocalResult | Format-List
    if($asusLocalResult.Result -notin @('Captured_RequiresOfflinePolicyAndMemoryValidation','OwnedTraceCleanupRequested')){exit 2}
}catch{Write-Error -Message $_.Exception.Message -ErrorAction Continue;exit 1}
