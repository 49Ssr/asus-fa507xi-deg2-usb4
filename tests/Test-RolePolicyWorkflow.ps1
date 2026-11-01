#requires -Version 5.1
[CmdletBinding()]
param([string]$UnsignedPackage='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$testRepo=Split-Path $PSScriptRoot -Parent
. (Join-Path $testRepo 'experimental\role-policy\Test-RolePolicy.ps1')
$script:Checks=0
function Check([bool]$Condition,[string]$Label){$script:Checks++;if(-not $Condition){throw ('FAIL: '+$Label)}}
function Reject([scriptblock]$Action,[string]$Label){$rejected=$false;try{& $Action|Out-Null}catch{$rejected=$true};Check $rejected $Label}
$script:Events=New-Object 'Collections.Generic.List[string]'
$testRoot=Join-Path $testRepo ('local\RolePolicyWorkflowChecks\'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($testRoot)
$preview=& (Join-Path $testRepo 'experimental\role-policy\Test-RolePolicy.ps1')
Check ($preview -match 'no installation by default') 'actual Preview'

# Real unsigned-package refusal; no host inventory or device operation is reached.
function Get-RpHost {throw 'HOST INVENTORY MUST NOT RUN IN SIGNATURE REFUSAL'}
if($UnsignedPackage){
    $hash=(Get-FileHash -LiteralPath (Join-Path $UnsignedPackage 'Usb4RolePolicy.sys')).Hash
    $message='';try{$null=Get-RpPreflight $UnsignedPackage $hash '' '' ''}catch{$message=$_.Exception.Message}
    Check ($message -like '*Microsoft-signed valid catalog*') 'real unsigned catalog rejected first'
}
$summary="Total Events  Lost      0`r`nTotal Format  Errors    0`r`nTotal Formats Unknown 2`r`n"
$enabled='Data role correction policy disabled. Forced UsbDeviceControllerEnabled:true.'
Check (Test-RpPolicyText $enabled $summary $true) 'Microsoft startup acceptance'
Check (-not(Test-RpPolicyText '' $summary $true)) 'missing acceptance blocks attachment'
Check (-not(Test-RpPolicyText ($enabled+' UsbDeviceControllerEnabled:false') $summary $true)) 'mixed startup policy blocks attachment'
Check (-not(Test-RpPolicyText $enabled ($summary.Replace('Lost      0','Lost      1')) $true)) 'lost events block acceptance'
Check (-not(Test-RpPolicyText $enabled ($summary.Replace('Errors    0','Errors    2')) $true)) 'format errors block acceptance'
Check (Test-RpPolicyText 'UsbDeviceControllerEnabled:false' $summary $false) 'default policy proof'
Check (-not(Test-RpPolicyText $enabled $summary $false)) 'override is not rollback'
Check (-not(Test-RpPolicyText ($enabled+' UsbDeviceControllerEnabled:false') $summary $false)) 'mixed policy refuses rollback'
$net=[pscustomobject]@{Sharing=@([pscustomobject]@{Guid='up';Shared=$true;Type=0},[pscustomobject]@{Guid='down';Shared=$true;Type=1},[pscustomobject]@{Guid='other';Shared=$false;Type=-1})}
Assert-RpSharing $net $net;Check $true 'same ICS accepted'
$changed=$net|ConvertTo-Json -Depth 4|ConvertFrom-Json;$changed.Sharing[1].Type=0
Reject {Assert-RpSharing $net $changed} 'changed ICS refused'
$inf=Join-Path $testRepo 'experimental\role-policy\Usb4RolePolicy.inf'
$good=[pscustomobject]@{Driver='oem123.inf';OriginalFileName=$inf;ProviderName='USB4 Research Experiment';Version='0.1.0.0';ClassName='Extension'}
Assert-RpOwnedPackage $good $script:RpInfHash;Check $true 'owned package fingerprint'
foreach($key in @('Driver','ProviderName','Version','ClassName')){
    $bad=$good|ConvertTo-Json|ConvertFrom-Json;$bad.$key='wrong'
    Reject {Assert-RpOwnedPackage $bad $script:RpInfHash} ('package rejects '+$key)
}
Reject {Assert-RpOwnedPackage $good ('0'*64)} 'package hash mismatch'

# Lifecycle doubles replace every mutation, trace, prompt, inventory and network call.
function Assert-RpDisconnected {$script:Events.Add('disconnected')}
function Read-Host {return 'STABLE'}
function Get-DeepNetworkSnapshot {return $net}
function Assert-RpDecoder {}
function Invoke-RpDeviceChange([string]$Directory,[scriptblock]$Action){$null=[IO.Directory]::CreateDirectory($Directory);$script:Events.Add('trace-start');try{& $Action}finally{$script:Events.Add('trace-stop')}}
function Start-Sleep {}
$script:Owned=@();$script:PnpExit=0;$script:FailProof=$false
function Get-RpOwnedPackages {return $script:Owned}
function Invoke-RpPnp([string[]]$Arguments,[string]$LogPath){
    $script:Events.Add(($Arguments -join '|'))
    if($Arguments[0] -eq '/add-driver'){
        $saved=Get-Content -LiteralPath (Join-Path (Split-Path $LogPath -Parent) 'state.private.json') -Raw|ConvertFrom-Json
        Check ($saved.PendingRollback -and $saved.Phase -eq 'InstallIntent') 'durable intent before install'
        $script:Owned=@($good)
    }
    if($Arguments[0] -eq '/delete-driver'){$script:Owned=@()}
    return $script:PnpExit
}
function Assert-RpPolicyTrace {
    if($script:FailProof){throw 'mock missing Microsoft acceptance'}
    return [pscustomobject]@{ExpectedDisabled=$args[1];TraceSHA256=('A'*64);DecodedSHA256=('B'*64)}
}
$script:RpRoot=$testRoot
$pre=[pscustomobject]@{Package=(Split-Path $inf -Parent);SysHash='';BootStamp='test-boot';HostState=[pscustomobject]@{Context=[pscustomobject]@{MachineHash='TEST';UcsiInstance='ACPI\USBC000\TEST'};BaseInf='ucsi.inf'}}
$run=Invoke-RpInstall $pre 'decoder' 'tmfs'
$state=Get-Content -LiteralPath (Join-Path $run 'state.private.json') -Raw|ConvertFrom-Json
Check ($state.Phase -eq 'PolicyAcceptedBeforeAttachment' -and $state.PendingRollback) 'install does not claim rollback or USB4 success'
Check ($state.PublishedInf -eq 'oem123.inf') 'exact OEM alias saved'
Check ($script:Events[1] -eq 'trace-start' -and $script:Events[2] -like '/add-driver*') 'trace precedes install'
$script:FailProof=$true
Reject {Invoke-RpInstall $pre 'decoder' 'tmfs'} 'missing Microsoft proof stops install flow'
$latest=Get-ChildItem -LiteralPath $testRoot -Directory|Where-Object FullName -ne $run|Select-Object -First 1
$failed=Get-Content -LiteralPath (Join-Path $latest.FullName 'state.private.json') -Raw|ConvertFrom-Json
Check ($failed.Phase -eq 'InstallNeedsRollback' -and $failed.PendingRollback) 'failed proof retains recovery'
$script:FailProof=$false;$script:PnpExit=3010
$script:Events.Clear()
Reject {Invoke-RpInstall $pre 'decoder' 'tmfs'} 'install requiring reboot stops'
Check (-not @($script:Events|Where-Object {$_ -like '/restart-device*'}).Count) 'no restart after reboot-required install'
Check ($script:Events.Contains('trace-stop')) 'trace stops after install failure'
$script:PnpExit=0

# Rollback does not rely on a healthy filtered UCSI device; mock the bound recovery read.
$script:Saved=$state
function Read-RpRun([string]$Directory,[switch]$ForRollback){Check ([bool]$ForRollback) 'recovery read allows failed device';return $script:Saved}
function Get-RpHost {return [pscustomobject]@{BaseInf='ucsi.inf';Lower=@();Upper=@()}}
function Get-CimInstance {return $null}
$script:Owned=@($good);$script:Events.Clear()
Invoke-RpRollback $run 'decoder' 'tmfs'
Check (-not $script:Saved.PendingRollback -and $script:Saved.Phase -eq 'RollbackVerified') 'rollback verified only after default proof'
Check ($script:Events.Contains('/delete-driver|oem123.inf|/uninstall')) 'only owned OEM package removed'
Check (-not @($script:Events|Where-Object {$_ -match '/force|/subtree|/reboot'}).Count) 'no force subtree or reboot'
$script:Events.Clear();Invoke-RpRollback $run 'decoder' 'tmfs'
Check ($script:Events.Count -eq 0) 'idempotent verified rollback'
$script:Saved.PendingRollback=$true;$script:Owned=@($good);$script:PnpExit=3010
Reject {Invoke-RpRollback $run 'decoder' 'tmfs'} 'rollback reboot required is pending'
Check ($script:Saved.PendingRollback -and $script:Saved.Phase -eq 'RollbackUnverified') 'no false rollback after 3010'
$script:PnpExit=0;$script:Owned=@($good);$script:Saved.PublishedInf='oem999.inf';$script:Events.Clear()
Reject {Invoke-RpRollback $run 'decoder' 'tmfs'} 'changed published alias refused'
Check (-not @($script:Events|Where-Object {$_ -like '/delete-driver*'}).Count) 'alias mismatch never deletes'
$script:Saved.PublishedInf='oem123.inf';$script:FailProof=$true;$script:Owned=@($good)
Reject {Invoke-RpRollback $run 'decoder' 'tmfs'} 'missing default-policy proof refuses rollback completion'
Check $script:Saved.PendingRollback 'unproved default remains pending'

# Attachment is a separate one-shot stage. A detected router/GPU is a valid result.
function Read-RpRun([string]$Directory,[switch]$ForRollback){return $script:Saved}
function Get-RpBootStamp {return 'test-boot'}
function Get-CimInstance {return [pscustomobject]@{State='Running'}}
function Save-DeepInventory {return [pscustomobject]@{Devices=@(
    [pscustomobject]@{InstanceId='USB4\VID_8087&PID_5786\TEST';Status='OK';Class='System';Properties=@{}},
    [pscustomobject]@{InstanceId='PCI\VEN_10DE&DEV_2702\TEST';Status='OK';Class='Display';Properties=@{'DEVPKEY_Device_Service'='nvlddmkm'}})}}
function Read-Host {return 'Y'}
$script:FailProof=$false;$script:Owned=@($good)
$script:Saved.Phase='PolicyAcceptedBeforeAttachment';$script:Saved.BootStamp='test-boot'
$script:Saved.StartedUtc=[DateTime]::UtcNow.ToString('o')
$etl=Join-Path $run 'startup\connection.etl';[IO.File]::WriteAllText($etl,'test trace only')
$script:Saved.PolicyProof.TraceSHA256=(Get-FileHash -LiteralPath $etl).Hash
$script:Saved.BootStamp='different-boot';$script:Events.Clear()
Reject {Invoke-RpObserve $run} 'stale boot blocks attachment'
Check ($script:Events.Count -eq 0) 'stale boot never starts trace or prompts'
$script:Saved.BootStamp='test-boot';$script:Saved.StartedUtc=[DateTime]::UtcNow.AddMinutes(-16).ToString('o')
Reject {Invoke-RpObserve $run} 'expired policy proof blocks attachment'
$script:Saved.StartedUtc=[DateTime]::UtcNow.ToString('o');$script:Saved.PolicyProof.TraceSHA256=('0'*64)
Reject {Invoke-RpObserve $run} 'changed ETL blocks attachment'
$script:Saved.PolicyProof.TraceSHA256=(Get-FileHash -LiteralPath $etl).Hash
$script:Saved.Phase='InstallNeedsRollback'
Reject {Invoke-RpObserve $run} 'unproved startup blocks attachment'
$script:Saved.Phase='PolicyAcceptedBeforeAttachment'
Invoke-RpObserve $run
Check ($script:Saved.Phase -eq 'ObservedRequiresOfflineAnalysis' -and $script:Saved.PendingRollback) 'one attachment retains rollback'
Check ($script:Saved.Observation.RouterHealthy -and $script:Saved.Observation.ExternalNvidiaBound) 'router/GPU success is recorded without aborting'
Reject {Invoke-RpObserve $run} 'no repeat attachment in same run'

# Exercise the real trace owner around failures, with native ETW calls doubled.
$owner=(Get-Content -LiteralPath (Join-Path $testRepo 'experimental\role-policy\Test-RolePolicy.ps1') -Raw)
$ast=[Management.Automation.Language.Parser]::ParseInput($owner,[ref]$null,[ref]$null)
$node=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-RpDeviceChange'},$true)
Invoke-Expression $node.Extent.Text
$script:StartsFail=$true;$script:ActionRan=$false;$script:Stopped=$false
function Start-RpTrace {if($script:StartsFail){throw 'mock trace unavailable'};return [ordered]@{Stopped=$false}}
function Stop-ConnectionTrace([object]$Trace,[string]$Directory){$Trace.Stopped=$true;$script:Stopped=$true}
Reject {Invoke-RpDeviceChange $testRoot {$script:ActionRan=$true}} 'install trace failure blocks action'
Check (-not $script:ActionRan) 'no install action without trace'
Invoke-RpDeviceChange $testRoot {$script:ActionRan=$true} $true
Check $script:ActionRan 'rollback action proceeds when tracing unavailable'
$script:StartsFail=$false
Reject {Invoke-RpDeviceChange $testRoot {throw 'mock operation failed'}} 'operation failure propagates'
Check $script:Stopped 'real trace owner stops on failure'
[pscustomobject]@{Checks=$script:Checks;Actual='Preview, parser, unsigned package, atomic private state files';Mocked='device/ETW/signing-success/install/restart/rollback/network';HardwareTested=$false}|ConvertTo-Json
