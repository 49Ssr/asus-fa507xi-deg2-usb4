#requires -Version 5.1
# Offline workflow checks. No ETW, device query, sleep or Administrator operation.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$repo=Split-Path $PSScriptRoot
$source=Join-Path $repo 'tools\Capture-USB4PartnerSwap.ps1'
$tokens=$null;$parseErrors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count){throw ($parseErrors|Out-String)}
. $source
$testRoot=Join-Path $repo ('local\PartnerSwapChecks\'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null

function Read-Host {param([string]$Prompt) if($script:scenario -eq 'Cancelled'){throw 'Simulated cancelled readiness prompt'};return ''}
function Start-Sleep {param([int]$Seconds) if($Seconds -ne 20){throw 'Unexpected recording duration'}}
function Get-NetAdapter {
    param([switch]$IncludeHidden,[string]$ErrorAction)
    $script:adapterCalls++
    if($script:scenario -eq 'AfterQueryFailure' -and $script:adapterCalls -eq 3){throw 'Simulated post-switch inventory failure'}
    $link='Up'
    if($script:adapterCalls -ge 3 -or $script:scenario -eq 'NoPeer' -or ($script:scenario -eq 'PeerLostBeforeTrace' -and $script:adapterCalls -eq 2)){$link='Disconnected'}
    $row=[pscustomobject]@{Name='Mock peer';InterfaceDescription='USB4(TM) P2P Network Adapter';Status=$link;LinkSpeed='20 Gbps'}
    if($script:scenario -eq 'TwoPeers'){return @($row,$row)}
    return $row
}
function Save-ConnectionInventory {
    param([string]$Directory,[string]$Phase)
    [IO.File]::WriteAllText((Join-Path $Directory ('devices-'+$Phase+'.json')),'{"Devices":[],"Error":null}')
}
function Start-ConnectionTrace {
    param([string]$Directory)
    $script:starts++
    if($script:scenario -eq 'StartFailure'){throw 'Simulated ETW start failure'}
    if($script:scenario -ne 'MissingEtl'){[IO.File]::WriteAllBytes((Join-Path $Directory 'connection.etl'),[byte[]]@(1,2,3))}
    return [ordered]@{Name='owned-mock-session';Stopped=$false;StopExitCode=$null}
}
function Stop-ConnectionTrace {
    param([object]$Trace,[string]$Directory)
    if($Trace.Name -ne 'owned-mock-session'){throw 'Attempted to stop an unrelated trace'}
    $script:stops++
    if($script:scenario -eq 'StopReportedFailure'){$Trace.StopExitCode=1;return}
    $Trace.StopExitCode=0;$Trace.Stopped=$true
    if($script:scenario -eq 'StopFailure'){throw 'Simulated stop-log failure after session stopped'}
}

$cases=@(
    @('Normal','Recorded',1,1),
    @('AfterQueryFailure','NotCompleted',1,1),
    @('StopFailure','NotCompleted',1,1),
    @('StopReportedFailure','NotCompleted',1,1),
    @('MissingEtl','NotCompleted',1,1),
    @('PeerLostBeforeTrace','NotCompleted',0,0),
    @('NoPeer','NotCompleted',0,0),
    @('TwoPeers','NotCompleted',0,0),
    @('Cancelled','NotCompleted',0,0),
    @('StartFailure','NotCompleted',1,0)
)
foreach($case in $cases){
    $script:scenario=[string]$case[0];$script:adapterCalls=0;$script:starts=0;$script:stops=0
    $dir=Join-Path $testRoot $script:scenario;New-Item -ItemType Directory -Path $dir|Out-Null
    $result=Invoke-PartnerSwapRecording $dir
    if($result.Result -ne $case[1] -or $script:starts -ne $case[2] -or $script:stops -ne $case[3]){throw ('Unexpected recording/cleanup result: '+$script:scenario)}
    $saved=Get-Content -LiteralPath (Join-Path $dir 'status.json') -Raw|ConvertFrom-Json
    if($saved.Result -ne $result.Result){throw 'Saved status disagrees with returned status'}
    if($null -ne $saved.ControllerStayedAwake -or $null -ne $saved.ExternalRouterObserved -or $null -ne $saved.GpuObserved -or $saved.PhysicalSwitchTimesVerified){throw 'Recording claimed unanalysed physical results'}
    if($script:scenario -eq 'Normal'){
        $after=Get-Content -LiteralPath (Join-Path $dir 'peer-after.json') -Raw|ConvertFrom-Json
        if(@($after)[0].Status -ne 'Disconnected'){throw 'Normal scenario must permit loss of the peer adapter after partner swap'}
        if(-not $saved.HandoffPromptUtc){throw 'Missing handoff prompt timestamp'}
    }
    if($script:scenario -eq 'StopFailure'){
        $trace=Get-Content -LiteralPath (Join-Path $dir 'trace-status.json') -Raw|ConvertFrom-Json
        if(-not $trace.StopError){throw 'Failed stop lost its diagnostic'}
    }
    Write-Output ('PASS '+$script:scenario)
}
Write-Output 'PASS Windows PowerShell parser'
Write-Output 'Ten mocked cleanup/guard cases passed. No hardware outcome tested.'
