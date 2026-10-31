#requires -Version 5.1
<# Short ETW rundown of the already-connected ASUS-Dell USB4 peer link.
   No LiveKD helper, controller restart, networking setup or firmware operation. #>
[CmdletBinding()]
param([ValidateSet('Preview','Capture')][string]$Mode='Preview')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Dot-sourcing imports the already exercised ETW helpers and resets its own params.
$peerRequestedMode=$Mode
. (Join-Path $PSScriptRoot 'Invoke-UcsiMemoryProbe.ps1')
if($peerRequestedMode -eq 'Preview'){
    Write-Output 'Keep ASUS and Dell directly connected with the DEG2 cable and their P2P adapters Up.'
    Write-Output 'Capture records three seconds of USB4 ETW, including provider rundown, and saves adapter state privately.'
    Write-Output 'No port reset, kernel helper, Internet sharing, IP/firewall, driver or firmware change.'
    exit 0
}
$peerIdentity=[Security.Principal.WindowsIdentity]::GetCurrent()
$peerPrincipal=New-Object Security.Principal.WindowsPrincipal($peerIdentity)
if(-not $peerPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Use Administrator PowerShell for the ETW session.'}
$peerModel=[string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS').SystemProductName
if($peerModel -notmatch '(?i)(^|[^a-z0-9])FA507XI([^a-z0-9]|$)'){throw 'Run this comparison on the ASUS FA507XI.'}
$peerAdapters=@(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object {$_.InterfaceDescription -match 'USB4.*P2P'})
if(@($peerAdapters|Where-Object {$_.Status -eq 'Up'}).Count -ne 1){throw 'Expected one Up USB4 P2P adapter. Keep the direct ASUS-Dell link connected.'}
$peerRun=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-peer-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $peerRun | Out-Null
$peerStatus=[ordered]@{Schema=1;Kind='PeerRundown';StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotCompleted';Error=$null;PhysicalRateMeasured=$false}
$peerTrace=$null
try {
    $peerBefore=@($peerAdapters|Select-Object Name,InterfaceDescription,Status,LinkSpeed)
    [IO.File]::WriteAllText((Join-Path $peerRun 'peer-before.json'),($peerBefore|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    Write-Host 'Recording the existing peer link for three seconds. Keep both ends connected.' -ForegroundColor Cyan
    $peerTrace=Start-ConnectionTrace $peerRun
    Start-Sleep -Seconds 3
    $peerAfter=@(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object {$_.InterfaceDescription -match 'USB4.*P2P'} | Select-Object Name,InterfaceDescription,Status,LinkSpeed)
    [IO.File]::WriteAllText((Join-Path $peerRun 'peer-after.json'),($peerAfter|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    if(@($peerAfter|Where-Object {$_.Status -eq 'Up'}).Count -ne 1){throw 'P2P link was not Up at the end; preserve the trace as a changed condition.'}
    $peerStatus.Result='Recorded'
} catch {
    $peerStatus.Error=$_.Exception.Message;Write-Warning $peerStatus.Error
} finally {
    if($null -ne $peerTrace){
        try{Stop-ConnectionTrace $peerTrace $peerRun}catch{$peerTrace.StopError=$_.Exception.Message;Write-Warning ('Own ETW session stop failed: '+$peerTrace.Name)}
        [IO.File]::WriteAllText((Join-Path $peerRun 'trace-status.json'),($peerTrace|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
        if(-not $peerTrace.Stopped){$peerStatus.Result='NotCompleted';$peerStatus.Error='Own ETW trace did not stop normally.'}
    }
    $peerStatus.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText((Join-Path $peerRun 'status.json'),($peerStatus|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    Write-Host ('Private results: '+$peerRun)
}
if($peerStatus.Result -ne 'Recorded'){exit 1}
Write-Output 'Peer rundown recorded. Adapter LinkSpeed is a virtual-NIC value; physical USB4 rate still requires trace analysis.'
exit 0
