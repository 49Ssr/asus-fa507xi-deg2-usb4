#requires -Version 5.1
<# Record a working ASUS-Dell peer link changing to the powered DEG2.
   ETW and private inventories only; no reset, kernel helper or configuration change. #>
[CmdletBinding()]
param([ValidateSet('Preview','Capture')][string]$Mode='Preview')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$swapRequestedMode=$Mode
. (Join-Path $PSScriptRoot 'Invoke-UcsiMemoryProbe.ps1')

function Write-PartnerSwapJson([string]$Path,[object]$Value) {
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
}
function Get-PartnerSwapPeer {
    $up=@(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object {
        $_.InterfaceDescription -match 'USB4.*P2P' -and $_.Status -eq 'Up'
    })
    if($up.Count -ne 1){throw 'Expected exactly one Up USB4 P2P adapter. Connect ASUS directly to Dell and keep both awake.'}
    return $up[0]
}
function Invoke-PartnerSwapRecording([string]$Directory) {
    $status=[ordered]@{Schema=1;Kind='PeerToDeg2PartnerSwap';StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotCompleted';Error=$null;PeerVerifiedUtc=$null;HandoffPromptUtc=$null;FinishedUtc=$null;PhysicalSwitchTimesVerified=$false;ControllerStayedAwake=$null;ExternalRouterObserved=$null;GpuObserved=$null}
    $trace=$null
    try {
        Write-Host 'Keep ASUS connected directly to Dell. DEG2 must already be powered in TB5 mode.'
        $null=Read-Host 'Keep the ASUS cable end attached throughout. Press Enter when ready; move the Dell end only at the green prompt'
        $before=Get-PartnerSwapPeer
        Save-ConnectionInventory $Directory 'before'
        # Recheck after the inventory, immediately before starting the trace.
        $before=Get-PartnerSwapPeer
        $status.PeerVerifiedUtc=[DateTime]::UtcNow.ToString('o')
        Write-PartnerSwapJson (Join-Path $Directory 'peer-before.json') ($before|Select-Object Name,InterfaceDescription,Status,LinkSpeed)
        $trace=Start-ConnectionTrace $Directory
        $status.HandoffPromptUtc=[DateTime]::UtcNow.ToString('o')
        Write-Host 'RECORDING: leave the ASUS end attached. Move ONLY the Dell end directly into the powered DEG2 upstream port now.' -ForegroundColor Green
        Write-Host 'Recording for twenty seconds. Do not reset or power-cycle anything during this window.'
        Start-Sleep -Seconds 20
        $after=@(Get-NetAdapter -IncludeHidden -ErrorAction Stop | Where-Object {$_.InterfaceDescription -match 'USB4.*P2P'} | Select-Object Name,InterfaceDescription,Status,LinkSpeed)
        Write-PartnerSwapJson (Join-Path $Directory 'peer-after.json') $after
        Save-ConnectionInventory $Directory 'after'
        # The peer adapter is expected to go down when its partner changes.
        # Successful recording does not establish a working external router/GPU.
        $status.Result='Recorded'
    } catch {
        $status.Error=$_.Exception.Message
        Write-Warning $status.Error
    } finally {
        if($null -ne $trace){
            try {Stop-ConnectionTrace $trace $Directory} catch {
                $trace.StopError=$_.Exception.Message
                $status.Result='NotCompleted'
                $status.Error='Own ETW session stop failed: '+$_.Exception.Message
                Write-Warning $status.Error
            }
            Write-PartnerSwapJson (Join-Path $Directory 'trace-status.json') $trace
            if(-not $trace.Stopped){$status.Result='NotCompleted';$status.Error='Own ETW session did not stop normally: '+$trace.Name}
        }
        if($status.Result -eq 'Recorded'){
            $etl=Join-Path $Directory 'connection.etl'
            if(-not(Test-Path -LiteralPath $etl -PathType Leaf)){$status.Result='NotCompleted';$status.Error='Trace file is missing.'}
            elseif((Get-Item -LiteralPath $etl).Length -eq 0){$status.Result='NotCompleted';$status.Error='Trace file is empty.'}
        }
        $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
        Write-PartnerSwapJson (Join-Path $Directory 'status.json') $status
        Write-Host ('Private results: '+$Directory)
    }
    return $status
}

if($MyInvocation.InvocationName -eq '.'){return}
if($swapRequestedMode -eq 'Preview'){
    Write-Output 'Start with the supplied DEG2 cable directly connecting ASUS and Dell, USB4 P2P Up, and DEG2 already powered in TB5 mode.'
    Write-Output 'Capture asks you to prepare, starts ETW on the working link, then gives a green prompt to move only the Dell cable end to DEG2.'
    Write-Output 'It records twenty seconds plus inventories, stops its own trace, and saves results privately. Actual switch times and awake state require analysis.'
    Write-Output 'No controller restart, LiveKD, driver/firmware/registry change, IP/firewall/sharing change or upload.'
    exit 0
}
if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit Windows PowerShell.'}
$swapIdentity=[Security.Principal.WindowsIdentity]::GetCurrent()
$swapPrincipal=New-Object Security.Principal.WindowsPrincipal($swapIdentity)
if(-not $swapPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Use Administrator PowerShell for the ETW session.'}
$swapModel=[string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS').SystemProductName
if($swapModel -notmatch '(?i)(^|[^a-z0-9])FA507XI([^a-z0-9]|$)'){throw 'Run this comparison on the ASUS FA507XI.'}
$null=Get-PartnerSwapPeer
$swapRun=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-partner-swap-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $swapRun | Out-Null
$swapResult=Invoke-PartnerSwapRecording $swapRun
if($swapResult.Result -ne 'Recorded'){exit 1}
Write-Output 'Partner handoff recorded. Check USB4 settings/Device Manager and report the result; the trace needs analysis before an awake-state or repair claim.'
exit 0
