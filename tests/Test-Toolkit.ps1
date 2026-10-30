#requires -Version 5.1
# Guard and command-plan tests only. No real disk, BCD, driver, or firmware writes.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'tools\NativeBoot.Common.ps1')
. (Join-Path $repo 'tools\Collect-USB4Test.ps1')
$script:checks=0
function Check {param([bool]$Condition,[string]$Message);$script:checks++;if(-not $Condition){throw $Message}}
function MustThrow {param([scriptblock]$Action,[string]$Message);$raised=$false;try{&$Action|Out-Null}catch{$raised=$true};Check $raised $Message}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $repo 'tools') -Filter '*.ps1'){
    $tokens=$null;$errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Check ($errors.Count -eq 0) ('Parser errors: '+$file.Name+' '+($errors|Out-String))
}
Check ((Assert-ContainedPath 'D:\test\local\NativeBoot\x.vhdx' 'D:\test\local') -eq 'D:\test\local\NativeBoot\x.vhdx') 'Valid contained path'
MustThrow {Assert-ContainedPath 'D:\test\local-escape\x' 'D:\test\local'} 'Sibling prefix must not pass'
MustThrow {Assert-ContainedPath 'D:\test\local\..\outside\x' 'D:\test\local'} 'Traversal must not pass'
Check ((ConvertTo-NativeArgument '') -eq '""') 'Empty native argument'
Check ((ConvertTo-NativeArgument 'D:\two words\') -eq '"D:\two words\\"') 'Trailing slash quoting'
MustThrow {ConvertTo-NativeArgument "x`ny"} 'Reject native newline'
$id='{ba4b0c9c-106a-4a10-9293-2a9dfcfb77c1}'
$vhd='D:\Projects\GitHub\usb4\local\NativeBoot\USB4-Test.vhdx'
$plan=@(Get-BootEntryArguments $id $vhd)
Check ($plan.Count -eq 8) 'Expected one create, six sets, one display-order operation'
Check (($plan[0] -join '|') -eq ('/create|'+$id+'|/d|USB4 test - temporary Windows|/application|OSLOADER')) 'Explicit newly allocated osloader'
Check ($plan[1][3] -eq 'vhd=[D:]\Projects\GitHub\usb4\local\NativeBoot\USB4-Test.vhdx') 'Exact VHD device path'
Check (($plan[-1] -join '|') -eq ('/displayorder|'+$id+'|/addlast')) 'Add only at end of display order'
Check (-not (($plan|ForEach-Object {$_ -join ' '}) -match '/default|/timeout|/bootsequence|testsigning|nointegrity|hypervisor|/import|bcdboot')) 'No original default, boot-file, or security changes'
MustThrow {Get-BootEntryArguments '{current}' $vhd} 'Reserved BCD aliases must not be accepted'
MustThrow {Get-BootEntryArguments $id 'D:\other.iso'} 'Only VHDX can become test device'
$entry=$id+"`nUSB4 test - temporary Windows`nvhd=[D:]"+$vhd.Substring(2)
Check (Test-BootEntryOwnership $entry $id $vhd) 'Own entry accepted'
Check (-not (Test-BootEntryOwnership $entry $id 'D:\elsewhere\USB4-Test.vhdx')) 'Other VHD rejected'
$creation=@(Get-VhdCreationCommands $vhd)
Check ($creation.Count -eq 2) 'Diskpart receives exactly create-file and exit'
Check ($creation[0] -eq ('create vdisk file="'+$vhd+'" maximum=65536 type=expandable')) 'Exact VHDX file creation command'
Check ($creation[1] -eq 'exit') 'Diskpart creation terminates'
MustThrow {Get-VhdCreationCommands "D:\bad`nclean.vhdx"} 'Diskpart command injection rejected'
MustThrow {Get-VhdCreationCommands 'D:\bad"path.vhdx'} 'Diskpart quote injection rejected'
function Get-DiskImage {param([string]$ImagePath);[pscustomobject]@{Attached=$script:attached}}
function Get-Disk {param([Parameter(ValueFromPipeline)]$Image);process{$script:disk}}
$script:attached=$true
$script:disk=[pscustomobject]@{Number=7;BusType=15;IsBoot=$false;IsSystem=$false;Size=[uint64](64GB);PartitionStyle='RAW'}
Check ((Assert-VirtualDiskTarget $vhd 7 -RequireRaw).Number -eq 7) 'Correct new virtual disk accepted'
$script:disk.BusType=17
MustThrow {Assert-VirtualDiskTarget $vhd 7} 'Physical NVMe rejected'
$script:disk.BusType=15;$script:disk.IsBoot=$true
MustThrow {Assert-VirtualDiskTarget $vhd 7} 'Boot disk rejected'
$script:disk.IsBoot=$false;$script:disk.IsSystem=$true
MustThrow {Assert-VirtualDiskTarget $vhd 7} 'System disk rejected'
$script:disk.IsSystem=$false
MustThrow {Assert-VirtualDiskTarget $vhd 8} 'Stale disk number rejected'
$script:disk.Size=[uint64](1TB)
MustThrow {Assert-VirtualDiskTarget $vhd 7} 'Wrong capacity rejected'
$script:disk.Size=[uint64](64GB);$script:disk.PartitionStyle='GPT'
MustThrow {Assert-VirtualDiskTarget $vhd 7 -RequireRaw} 'Preinitialized disk rejected'
$script:attached=$false
MustThrow {Assert-VirtualDiskTarget $vhd 7} 'Detached image rejected'
$rows=@(
    [pscustomobject]@{Id='USB4\ROOT_DEVICE_ROUTER&VID_1022';Class='USB';Status='Started';Problem='0';Name='root'}
    [pscustomobject]@{Id='USB4\VIRTUAL_POWER_PDO\x';Class='USB';Status='Started';Problem='0';Name='power'}
    [pscustomobject]@{Id='USB\VID_8087&PID_5787\x';Class='USB';Status='Started';Problem='0';Name='fallback'}
)
Check (@(Get-ExternalRouters $rows).Count -eq 0) 'Fallback hub is not an external USB4 router'
$rows+=[pscustomobject]@{Id='USB4\VID_8087&PID_5786\x';Class='USB';Status='Started';Problem='0';Name='dock'}
Check (@(Get-ExternalRouters $rows).Count -eq 1) 'Real external router recognized'
Check (@(Get-PreflightIssues @()).Count -eq 5) 'Missing prerequisites are not reported as a valid negative test'
[xml]$mockXml='<PnpUtil><Device InstanceId="USB4\VID_8087&amp;PID_5786\mock"><DeviceDescription>Test dock</DeviceDescription><Status>Started</Status><Properties><Property Key="DEVPKEY_Device_DriverVersion"><Value>1.0</Value></Property></Properties></Device></PnpUtil>'
$parsed=@(Read-DeviceRows $mockXml)
Check ($parsed.Count -eq 1 -and $parsed[0].Driver -eq '' -and $parsed[0].Version -eq '1.0') 'Missing XML fields are safe under StrictMode'
Check (@(Get-ExternalRouters $parsed).Count -eq 1) 'XML-decoded external router recognized'
MustThrow {Find-ResultBridge ([pscustomobject]@{RepositoryRelativePath='..\outside';BridgeId='test'})} 'Result bridge traversal rejected'
MustThrow {Find-ResultBridge ([pscustomobject]@{RepositoryRelativePath='D:\outside';BridgeId='test'})} 'Absolute result bridge rejected'
$prepare=Get-Content -LiteralPath (Join-Path $repo 'tools\Prepare-USB4Test.ps1') -Raw
Check (-not ($prepare -match '(?im)^\s*clean\s*$|Clear-Disk|Remove-Partition|Resize-Partition|bcdboot')) 'No physical partition deletion/resize or boot-file replacement'
Check ($prepare.Contains('Assert-VirtualDiskTarget -ImagePath $vhdPath -DiskNumber $number -RequireRaw')) 'Raw VHD guard present before initialization'
Write-Host ('Passed '+$script:checks+' checks. No disk, BCD, driver-installation, or firmware operations executed.') -ForegroundColor Green
