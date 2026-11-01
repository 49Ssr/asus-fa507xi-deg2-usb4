#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$source=Join-Path $root 'tools\Capture-USB4ColdStart.ps1'
. $source
$script:checks=0
function Check([bool]$Value,[string]$Label){if(-not $Value){throw $Label};$script:checks++}
function Reject([scriptblock]$Action,[string]$Label){$rejected=$false;try{& $Action}catch{$rejected=$true};Check $rejected $Label}
Check (@(Get-ColdPropertyData ([pscustomobject]@{Type='Empty'})).Count -eq 0) 'Missing Data on Empty property handled'
Check ((Get-ColdPropertyData ([pscustomobject]@{Type='String';Data='fixture'})) -ceq 'fixture') 'Present property data retained'
Reject {Get-ColdPropertyData ([pscustomobject]@{Type='String'})} 'Missing nonempty property data rejected'
$m=Get-ColdMilestones @([pscustomobject]@{Status='OK';InstanceId='USB4\VID_8087&PID_5786\fixture'},[pscustomobject]@{Status='OK';InstanceId='PCI\VEN_10DE&DEV_2702\fixture'})
Check ($m.ExternalRouter -and $m.GpuPresent -and -not $m.Billboard) 'Working milestones'
$m=Get-ColdMilestones @([pscustomobject]@{Status='OK';InstanceId='USB\VID_041F&PID_D002\fixture'})
Check ($m.Billboard -and -not $m.ExternalRouter -and -not $m.GpuPresent) 'Billboard is not success'
$m=Get-ColdMilestones @([pscustomobject]@{Status='Error';InstanceId='USB4\VID_8087&PID_5786\fixture'})
Check (-not $m.ExternalRouter) 'Unhealthy router is not qualified'
$m=Get-ColdMilestones @()
Check (-not $m.ExternalRouter -and -not $m.GpuPresent -and -not $m.Billboard) 'Empty inventory is not success'
$record=[pscustomobject]@{Kind='Usb4ColdStartObservation';MachineHash='fixture';BootStamp='boot-one';Phase='Prepared';SourceSHA256=(Get-FileHash $source).Hash;CommonSHA256=(Get-FileHash (Join-Path $root 'tools\Usb4Capture.Common.ps1')).Hash}
$context=[pscustomobject]@{MachineHash='fixture';BootStamp='boot-two'}
$null=Assert-ColdRecord $record $context $true;Check $true 'Changed boot accepted'
$context.BootStamp='boot-one';Reject {Assert-ColdRecord $record $context $true} 'Same boot rejected'
$context.BootStamp='boot-two';$context.MachineHash='other';Reject {Assert-ColdRecord $record $context $true} 'Another machine rejected'
$context.MachineHash='fixture';$record.Phase='Attempted';Reject {Assert-ColdRecord $record $context $true} 'Repeat attempt rejected'
$record.Phase='Prepared';$record.SourceSHA256='wrong';Reject {Assert-ColdRecord $record $context $true} 'Changed source rejected'
$record.SourceSHA256=(Get-FileHash $source).Hash;$record.CommonSHA256='wrong';Reject {Assert-ColdRecord $record $context $true} 'Changed shared source rejected'
Reject {Assert-ColdPath (Join-Path $root 'local\ColdStart-other\bad')} 'Sibling-prefix escape rejected'
Reject {Assert-ColdPath (Join-Path $script:ColdRoot '..\escape')} 'Parent escape rejected'
$null=Assert-ColdPath (Join-Path $script:ColdRoot 'fixture');Check $true 'Owned child path accepted'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
Check ($errors.Count -eq 0) 'PS5.1 parse'
$commands=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst]},$true)|ForEach-Object {$_.GetCommandName()})
foreach($forbidden in @('Restart-Computer','Stop-Computer','Set-ItemProperty','Remove-ItemProperty','Set-PnpDevice','Disable-PnpDevice','Enable-PnpDevice','Register-ScheduledTask','Set-NetAdapter','Invoke-Usb4FirmwareQueries','Invoke-DeepRecorders')){
    Check ($commands -notcontains $forbidden) ('No '+$forbidden)
}
Check ((Get-Content $source -Raw) -notmatch '(?im)^\s*&?\s*(shutdown|pnputil|bcdedit)(\.exe)?\s') 'No native mutation commands'
Write-Output ('Cold-start checks passed: '+$script:checks+' (no hardware/boot operations executed).')
