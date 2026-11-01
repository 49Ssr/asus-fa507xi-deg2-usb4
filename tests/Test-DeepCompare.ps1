#requires -Version 5.1
# No ETW sessions, firmware commands, setting changes or new kernel snapshots.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repoRoot=Split-Path $PSScriptRoot -Parent
. (Join-Path $repoRoot 'tools\Capture-USB4DeepCompare.ps1')
$script:originalDumpHeaderReader=(Get-Command Read-DeepDumpHeader).ScriptBlock
$script:deepChecks=0
function Check([bool]$Value,[string]$Why){if(-not $Value){throw $Why};$script:deepChecks++}
function MustThrow([scriptblock]$Code,[string]$Why){$failed=$false;try{& $Code|Out-Null}catch{$failed=$true};Check $failed $Why}
function Write-Host {param($Object,$ForegroundColor)}
function Write-Warning {param($Message)}
function New-ItemProperty {throw 'No registry writes in validation'}
function Restart-Computer {throw 'No restart in validation'}
$fixtureRoot=Join-Path ([IO.Path]::GetTempPath()) ('Usb4DeepCompareTests-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($fixtureRoot)
Initialize-DeepNative
# Exercise the precise native response shape that stopped the returned Dell run.
$script:pnpReplies=@(
    [pscustomobject]@{KeyName='DEVPKEY_Device_Service';Data='nvlddmkm'},
    [pscustomobject]@{KeyName='DEVPKEY_Device_LocationPaths';Type='Empty'},
    [pscustomobject]@{KeyName='DEVPKEY_Device_DriverVersion';Data=$null},
    [pscustomobject]@{KeyName='DEVPKEY_Device_ProblemCode';Data=0},
    [pscustomobject]@{KeyName='DEVPKEY_Device_Parent';Data=@('one','two')},
    [pscustomobject]@{KeyName='Unexpected';Data='ignored'},
    [pscustomobject]@{Type='Empty'})
function Get-PnpDeviceProperty { [CmdletBinding()]param($InstanceId,$KeyName);return $script:pnpReplies }
try{
    $values=Get-DeepPnpProperties 'fixture' @('DEVPKEY_Device_Service','DEVPKEY_Device_LocationPaths','DEVPKEY_Device_DriverVersion','DEVPKEY_Device_ProblemCode','DEVPKEY_Device_Parent','Absent')
    Check ($values.Values['DEVPKEY_Device_Service'] -eq 'nvlddmkm') 'Available binding preserved'
    Check (-not $values.Values.ContainsKey('DEVPKEY_Device_LocationPaths')) 'Missing Data member stays unavailable'
    Check (@($values.Issues|Where-Object Reason -eq 'ReplyHasNoDataMember').Count -eq 1) 'Original Dell failure shape explicitly recorded'
    Check (@($values.Issues|Where-Object Reason -eq 'NullData').Count -eq 1) 'Null data distinguished'
    Check ($values.Values.ContainsKey('DEVPKEY_Device_ProblemCode') -and $values.Values['DEVPKEY_Device_ProblemCode'] -eq 0) 'Valid zero preserved'
    Check ($values.Values['DEVPKEY_Device_Parent'].Count -eq 2) 'Array metadata preserved'
    Check (-not $values.Values.ContainsKey('Unexpected')) 'Unrequested response ignored'
    Check (@($values.Issues|Where-Object Reason -eq 'ReplyHasNoKeyName').Count -eq 1) 'Malformed key recorded'
    Check (@($values.Issues|Where-Object Reason -eq 'NoReplyForRequestedKey').Count -eq 1) 'Missing requested reply recorded'
    $script:pnpReplies=@([pscustomobject]@{KeyName='DEVPKEY_Device_Service';Type='Empty'})
    $unknown=Get-DeepPnpProperties 'fixture' @('DEVPKEY_Device_Service')
    $device=[pscustomobject]@{InstanceId='PCI\VEN_10DE&DEV_2702\MOCK';Status='OK';Class='Display';Properties=$unknown.Values}
    $milestone=Get-DeepMilestone ([pscustomobject]@{Devices=@($device)})
    Check (-not $milestone.ExternalNvidiaBound) 'Missing critical binding cannot qualify a GPU'
}finally{Remove-Item -LiteralPath Function:\Get-PnpDeviceProperty}

# Read-only integration, deliberately not mocked: this path was missing from the
# first qualification and must succeed before another donor-laptop run.
$realInventory=Save-DeepInventory $fixtureRoot 'real-readonly-qualification'
Check ($realInventory.Devices.Count -gt 0) 'Actual scoped inventory succeeds under StrictMode'
$issueCount=@($realInventory.Devices|ForEach-Object {$_.PropertyIssues}|Where-Object Reason -eq 'ReplyHasNoDataMember').Count
Check ($issueCount -gt 0) 'Actual Windows missing-Data replies handled without losing inventory'
$ucsiDevices=@(Get-PnpDevice -PresentOnly -ErrorAction Stop|Where-Object {$_.InstanceId -match '^ACPI\\USBC000\\'})
Check ($ucsiDevices.Count -eq 1) 'Read-only qualification identifies the single UCSI device'
$staticRoot=Join-Path $fixtureRoot 'ActualStaticInputs';$null=[IO.Directory]::CreateDirectory($staticRoot)
Save-DeepInputs $staticRoot ([pscustomobject]@{Target='ReadOnlyQualification';UcsiInstance=$ucsiDevices[0].InstanceId})
$inputManifest=Get-Content -LiteralPath (Join-Path $staticRoot 'driver-inputs.private.json') -Raw|ConvertFrom-Json
Check ($inputManifest.Count -eq 14) 'Actual static input collector copies all fourteen installed driver images'
foreach($row in $inputManifest){Check ((Get-FileHash -LiteralPath (Join-Path $staticRoot ('DriverImages\'+$row.Name)) -Algorithm SHA256).Hash -ceq $row.SHA256) 'Actual static driver copy hash verified'}
MustThrow {Resolve-DeepDriverPath 'arbitrary.sys'} 'Driver resolver refuses unrelated images'
$intel=[pscustomobject]@{InstanceId='PCI\VEN_8086&DEV_A73E';FriendlyName='USB4 Host Router';Status='OK'}
$amd=[pscustomobject]@{InstanceId='PCI\VEN_1022&DEV_1668';FriendlyName='USB4 Host Router';Status='OK'}
Assert-DeepHostIdentity 'Dell Inc.' 'Latitude 5540' @($intel) Dell;Check $true 'Dell target passes'
Assert-DeepHostIdentity 'ASUSTeK COMPUTER INC.' 'ASUS TUF Gaming A15 FA507XI_FA507XI' @($amd) Asus;Check $true 'ASUS target passes'
MustThrow {Assert-DeepHostIdentity 'Dell Inc.' 'Latitude 5550' @($intel) Dell} 'Wrong Dell model fails'
MustThrow {Assert-DeepHostIdentity 'ASUSTeK' 'FA507XI' @($amd) Dell} 'ASUS refuses Dell entry'
MustThrow {Assert-DeepHostIdentity 'Dell Inc.' 'Latitude 5540' @($amd) Dell} 'Wrong host vendor fails'
foreach($path in @('..\x','x\..\y','C:\x','\\server\x','x:y','x.\y','x \y','')){MustThrow {Assert-DeepRelative $path} 'Unsafe relative path refused'}
foreach($path in @('x.json','DriverImages\ACPI.sys','Dump\full-live-kernel.dmp')){Assert-DeepRelative $path;Check $true 'Owned relative path passes'}
$rootDir=[IO.Path]::GetPathRoot($fixtureRoot);Assert-LocalPath $rootDir|Out-Null;Check $true 'Drive-root argument has no parent-path failure'

# Real Windows firmware API reads, not AML execution or firmware requests.
$acpiRoot=Join-Path $fixtureRoot 'ActualAcpi';Save-DeepAcpi $acpiRoot
$acpi=Get-Content -LiteralPath (Join-Path $acpiRoot 'acpi-index.private.json') -Raw|ConvertFrom-Json
Check (@($acpi.Tables|Where-Object {$_.Header.Signature -eq 'DSDT'}).Count -eq 1) 'Actual DSDT export works'
Check $acpi.OnlyFirstDuplicateAccessible 'Duplicate-table coverage is disclosed'
Check (-not(Test-Path -LiteralPath (Join-Path $acpiRoot 'MSDM.bin'))) 'Activation table excluded'
$dsdt=[IO.File]::ReadAllBytes((Join-Path $acpiRoot 'DSDT.bin'));$bad=[byte[]]$dsdt.Clone();$bad[9]=$bad[9]-bxor 1
MustThrow {Get-DeepAcpiHeader $bad DSDT} 'Bad checksum refuses export'
MustThrow {Get-DeepAcpiHeader $dsdt SSDT} 'Signature mismatch refused'
MustThrow {Get-DeepAcpiHeader ([byte[]]@(1,2)) DSDT} 'Short table refused'

# Existing ASUS dump: validates only file parsing, not a new hardware capture.
$oldDump=Join-Path $repoRoot 'local\KernelDump\livedump.DMP'
if(Test-Path -LiteralPath $oldDump){$header=Read-DeepDumpHeader $oldDump ([datetime]::MinValue);Check $header.HeaderValidated 'Actual retained dump header passes';MustThrow {Read-DeepDumpHeader $oldDump ([DateTime]::UtcNow.AddYears(1))} 'Stale dump refused'}
$fakeDump=Join-Path $fixtureRoot 'synthetic.dmp';$bytes=New-Object byte[] 8192
[Text.Encoding]::ASCII.GetBytes('PAGEDU64').CopyTo($bytes,0);[BitConverter]::GetBytes([uint32]0x8664).CopyTo($bytes,48);[BitConverter]::GetBytes([uint32]0x161).CopyTo($bytes,56)
[IO.File]::WriteAllBytes($fakeDump,$bytes);$null=Read-DeepDumpHeader $fakeDump ([DateTime]::MinValue);Check $true 'Synthetic live-kernel header passes'
$bytes[0]=0;[IO.File]::WriteAllBytes($fakeDump,$bytes);MustThrow {Read-DeepDumpHeader $fakeDump ([DateTime]::MinValue)} 'Wrong dump magic refused'

# Compress/split, then reconstruct independently with framework gzip decompression.
foreach($kind in @('Empty','Random','Repeated')){
    $raw=Join-Path $fixtureRoot ($kind+'.bin')
    if($kind -eq 'Empty'){$data=New-Object byte[] 0}elseif($kind -eq 'Random'){$data=New-Object byte[] (3MB);$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($data)}finally{$rng.Dispose()}}else{$data=New-Object byte[] (6MB);for($i=0;$i -lt $data.Length;$i++){$data[$i]=[byte]($i%13)}}
    [IO.File]::WriteAllBytes($raw,$data);$gzip=Join-Path $fixtureRoot ($kind+'.gz')
    $receipt=[Usb4DeepCompare.Native]::Compress($raw,$gzip)
    Check ($receipt.Sha256 -ceq (Get-FileHash -LiteralPath $raw -Algorithm SHA256).Hash) 'Compression hashes raw bytes'
    MustThrow {[Usb4DeepCompare.Native]::Compress($raw,$gzip)} 'Compression refuses overwrite'
    $partsRoot=Join-Path $fixtureRoot ($kind+'-parts');$null=[IO.Directory]::CreateDirectory($partsRoot)
    $parts=@([Usb4DeepCompare.Native]::SplitCopy($gzip,$partsRoot,256KB));$joined=New-Object IO.MemoryStream
    try{
        foreach($part in $parts){Check ($part.Bytes -le 256KB) 'Part size bound';$partPath=Join-Path $partsRoot $part.Name;Check ((Get-FileHash -LiteralPath $partPath -Algorithm SHA256).Hash -ceq $part.Sha256) 'Read-back hash';$partBytes=[IO.File]::ReadAllBytes($partPath);$joined.Write($partBytes,0,$partBytes.Length)}
        Check ($joined.Length -eq (Get-Item -LiteralPath $gzip).Length) 'All gzip bytes preserved'
        $joined.Position=0;$decompress=New-Object IO.Compression.GZipStream($joined,[IO.Compression.CompressionMode]::Decompress,$true);$rebuilt=Join-Path $fixtureRoot ($kind+'-rebuilt.bin');$dest=[IO.File]::Create($rebuilt)
        try{$decompress.CopyTo($dest)}finally{$decompress.Dispose();$dest.Dispose()}
        Check ((Get-FileHash -LiteralPath $rebuilt -Algorithm SHA256).Hash -ceq $receipt.Sha256) 'Independent reconstructed raw hash matches'
    }finally{$joined.Dispose()}
    MustThrow {[Usb4DeepCompare.Native]::SplitCopy($gzip,$partsRoot,256KB)} 'Transport refuses overwriting existing parts'
}
MustThrow {[Usb4DeepCompare.Native]::SplitCopy('none','none',4GB)} 'FAT32-unsafe oversized part plan refused'

$dellInventory=Join-Path $repoRoot 'local\DellControl\Results\20261031-212220-Dell-DEG2-fa016b24\devices-passive.json'
if(Test-Path -LiteralPath $dellInventory){$actual=Get-Content -LiteralPath $dellInventory -Raw|ConvertFrom-Json;$m=Get-DeepMilestone $actual;Check ($m.RouterHealthy -and $m.ExternalNvidiaBound) 'Actual retained Dell GPU/router inventory matches'}

# Mocked capture lifecycle. Built-in trace and hardware/dump acquisition never run.
$script:deepScenario='Good';$script:starts=0;$script:stops=0;$script:readCount=0
$empty=[pscustomobject]@{Devices=@()}
$working=[pscustomobject]@{Devices=@([pscustomobject]@{InstanceId='USB4\VID_8087&PID_5786\MOCK';Status='OK';Class='USB';Properties=@{}},[pscustomobject]@{InstanceId='PCI\VEN_10DE&DEV_2702\MOCK';Status='OK';Class='Display';Properties=@{DEVPKEY_Device_Service='nvlddmkm'}})}
function Save-DeepInventory {param($Directory,$Label)
    if($Label -eq 'before'){if($script:deepScenario -eq 'AlreadyAttached'){return $working};return $empty}
    if($script:deepScenario -eq 'ControlMissing'){return $empty}
    if($Label -eq 'after-dump' -and $script:deepScenario -eq 'LostDuringDump'){return $empty}
    return $working
}
function Save-DeepInputs {param($Directory,$Context);if($script:deepScenario -eq 'InputsFail'){throw 'mock input failure'}}
function Get-DeepNetworkSnapshot {return @{Mock=$true}}
function Read-Host {param($Prompt);$script:readCount++;return $fakeDump}
function Open-DeepTaskManager {}
function Start-Sleep {param($Seconds)}
function Start-ConnectionTrace {param($Directory);$script:starts++;[IO.File]::WriteAllBytes((Join-Path $Directory 'connection.etl'),[byte[]]@(1));return @{Name='USB4_Ucsi_0123456789ab';Stopped=$false}}
function Stop-ConnectionTrace {param($Trace,$Directory);Check ($Trace.Name -eq 'USB4_Ucsi_0123456789ab') 'Only owned trace stops';$script:stops++;$Trace.Stopped=$true}
function Read-DeepDumpHeader {param($Path,$NotBefore);if($script:deepScenario -eq 'BadDump'){throw 'mock invalid dump'};return @{Path=$Path;Bytes=8192;LastWriteUtc=[DateTime]::UtcNow.ToString('o')}}
foreach($case in @('Good','AlreadyAttached','InputsFail','ControlMissing','LostDuringDump','BadDump')){
    $script:deepScenario=$case;$script:starts=0;$script:stops=0;$script:readCount=0
    $dir=Join-Path $fixtureRoot $case;$null=[IO.Directory]::CreateDirectory($dir)
    $r=Invoke-DeepCapture ([pscustomobject]@{Target='Dell'}) $dir
    if($case -eq 'Good'){Check ($r.Result -eq 'Captured_RequiresOfflinePolicyAndMemoryValidation' -and $null -ne $r.Dump) 'Good capture qualifies acquisition only';Check ($script:starts -eq 1 -and $script:stops -eq 1) 'Trace starts/stops once'}
    elseif($case -in @('AlreadyAttached','InputsFail')){Check ($script:starts -eq 0 -and $script:stops -eq 0) 'Failed preflight sends no trace/dump operation'}
    elseif($case -eq 'LostDuringDump'){Check ($null -ne $r.Dump -and -not $r.DumpBaselineQualified -and $null -ne $r.Error) 'Changed control preserves snapshot without qualifying it';Check ($script:stops -eq 1) 'Failure closes owned trace'}
    else{Check ($null -eq $r.Dump -and $null -ne $r.Error) 'Bad baseline/dump refuses qualification';Check ($script:stops -eq 1) 'Failure closes owned trace'}
    Check ($r.FirmwareCommandsSent -eq 0 -and -not $r.SettingsChanged -and -not $r.LiveKernelHelperLoaded) 'Passive operation declaration'
    Check (Test-Path -LiteralPath (Join-Path $dir 'status.json')) 'Outcome retained'
}

# Real source staging/return-copy integration on isolated temporary folders.
$script:DeepWorkRoot=Join-Path $fixtureRoot 'Owned'
$sourceKit=Join-Path $fixtureRoot 'SourceKit';$null=[IO.Directory]::CreateDirectory($sourceKit)
$names=@('Capture-USB4DeepCompare.ps1','Usb4Capture.Common.ps1','deep-compare\DeepCapture.Native.cs','START-DELL.cmd','START-ASUS.cmd','RETURN.cmd','STOP-TRACE.cmd','README.txt')
$fileRecords=@(foreach($name in $names){$path=Join-Path $sourceKit $name;$null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent));[IO.File]::WriteAllText($path,('fixture '+$name));@{Path=$name;SHA256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}})
$bundleId='0123456789abcdef0123456789abcdef'
Write-DeepJson (Join-Path $sourceKit 'bundle-manifest.json') @{Schema=1;Kind='USB4DeepCompare';BundleId=$bundleId;Files=$fileRecords}
$null=Read-DeepBundle $sourceKit;Check $true 'Actual bundle verification passes'
$staged=Join-Path $script:DeepWorkRoot 'Kits\qualified'
Copy-DeepBundle $sourceKit $staged;Check ((Read-DeepBundle $staged).Files.Count -eq 8) 'Actual staging read-back matches all eight files'
MustThrow {Copy-DeepBundle $sourceKit $staged} 'Staging refuses an existing folder'
MustThrow {Copy-DeepBundle $sourceKit (Join-Path $fixtureRoot 'outside')} 'Staging outside owned root refused'
[IO.File]::AppendAllText((Join-Path $sourceKit 'README.txt'),'tamper')
MustThrow {Read-DeepBundle $sourceKit} 'Changed source hash refused'
MustThrow {Copy-DeepBundle $sourceKit (Join-Path $script:DeepWorkRoot 'Kits\tampered')} 'Tampered bundle refuses staging'
Check (-not(Test-Path -LiteralPath (Join-Path $script:DeepWorkRoot 'Kits\tampered'))) 'No staging directory created after integrity failure'

function Get-DeepMachineHash {return 'TEST-MACHINE'}
$returnRun=Join-Path $script:DeepWorkRoot 'Runs\fixture-run';$null=[IO.Directory]::CreateDirectory($returnRun)
Write-DeepJson (Join-Path $returnRun 'run.private.json') @{Kind='USB4DeepCompareRun';MachineHash='TEST-MACHINE';Run=$returnRun;BundleId=$bundleId;Target='Dell'}
Write-DeepJson (Join-Path $returnRun 'status.json') @{Result='NotCompleted';Dump=$null}
Write-DeepJson (Join-Path $returnRun 'trace-status.json') @{Name='USB4_Ucsi_0123456789ab';Stopped=$true}
[IO.File]::WriteAllBytes((Join-Path $returnRun 'connection.etl'),([byte[]]@(1,2,3,4)))
[IO.File]::WriteAllBytes((Join-Path $returnRun 'empty.txt'),(New-Object byte[] 0))
$usbKit=Join-Path $fixtureRoot 'FakeUsbKit';$null=[IO.Directory]::CreateDirectory($usbKit)
Write-DeepJson (Join-Path $usbKit 'bundle-manifest.json') @{Kind='USB4DeepCompare';BundleId=$bundleId}
$script:usbFree=1GB
function Get-DeepDrive {param($Path)
    if($Path -eq $usbKit){return [pscustomobject]@{Bus='USB';IsBoot=$false;IsSystem=$false;FileSystem='FAT32';Free=$script:usbFree}}
    return [pscustomobject]@{Bus='NVMe';FileSystem='NTFS';Free=10GB;IsBoot=$true;IsSystem=$true}
}
$copied=Export-DeepReturn $returnRun $usbKit
$returnManifest=Get-Content -LiteralPath (Join-Path $copied 'RETURN-MANIFEST.private.json') -Raw|ConvertFrom-Json
Check ($returnManifest.Complete -and $returnManifest.OriginalsRetained) 'Actual return copy completes with originals retained'
Check (-not $returnManifest.FullDumpIncluded -and $returnManifest.CaptureResult -eq 'NotCompleted') 'Incomplete capture cannot be presented as a full-dump result'
foreach($file in $returnManifest.Files){
    $joined=New-Object IO.MemoryStream
    try{
        foreach($part in $file.Parts){$path=Join-Path (Join-Path $copied $file.PartDirectory) $part.Name;Check ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ceq $part.Sha256) 'Return part verified';$bytes=[IO.File]::ReadAllBytes($path);$joined.Write($bytes,0,$bytes.Length)}
        $joined.Position=0;$gzip=New-Object IO.Compression.GZipStream($joined,[IO.Compression.CompressionMode]::Decompress,$true);$raw=New-Object IO.MemoryStream
        try{$gzip.CopyTo($raw);$sha=[Security.Cryptography.SHA256]::Create();try{$actualHash=[BitConverter]::ToString($sha.ComputeHash($raw.ToArray())).Replace('-','')}finally{$sha.Dispose()};Check ($actualHash -ceq $file.RawSHA256 -and $raw.Length -eq $file.RawBytes) 'Actual return manifest independently reconstructs exact source'}finally{$gzip.Dispose();$raw.Dispose()}
    }finally{$joined.Dispose()}
}
Set-Item -LiteralPath Function:\Read-DeepDumpHeader -Value $script:originalDumpHeaderReader
# Recreate an independent header fixture; the earlier bytes variable was reused.
$dumpBytes=New-Object byte[] 8192
[Text.Encoding]::ASCII.GetBytes('PAGEDU64').CopyTo($dumpBytes,0);[BitConverter]::GetBytes([uint32]0x8664).CopyTo($dumpBytes,48);[BitConverter]::GetBytes([uint32]0x161).CopyTo($dumpBytes,56)
[IO.File]::WriteAllBytes($fakeDump,$dumpBytes)
$fullHeader=Read-DeepDumpHeader $fakeDump ([DateTime]::MinValue)
Write-DeepJson (Join-Path $returnRun 'status.json') @{Result='NotCompleted';Dump=$fullHeader}
$fullCopied=Export-DeepReturn $returnRun $usbKit
$fullManifest=Get-Content -LiteralPath (Join-Path $fullCopied 'RETURN-MANIFEST.private.json') -Raw|ConvertFrom-Json
Check ($fullManifest.FullDumpIncluded -and @($fullManifest.Files|Where-Object RelativePath -eq 'Dump\full-live-kernel.dmp').Count -eq 1) 'Full dump source survives metadata revalidation and reaches return manifest'
Check (Test-Path -LiteralPath $fakeDump) 'Original dump retained after packaging'
$countBefore=@(Get-ChildItem -LiteralPath (Join-Path $usbKit 'RETURNED') -Directory).Count
$script:usbFree=0
MustThrow {Export-DeepReturn $returnRun $usbKit} 'Insufficient USB space refuses copying'
Check (@(Get-ChildItem -LiteralPath (Join-Path $usbKit 'RETURNED') -Directory).Count -eq $countBefore) 'No new USB result folder after free-space failure'
Check (Test-Path -LiteralPath (Join-Path $returnRun 'connection.etl')) 'Original trace preserved after failed transfer'
$script:usbFree=1GB
Write-DeepJson (Join-Path $returnRun 'run.private.json') @{Kind='USB4DeepCompareRun';MachineHash='ANOTHER-MACHINE';Run=$returnRun;BundleId=$bundleId;Target='Dell'}
MustThrow {Export-DeepReturn $returnRun $usbKit} 'Another machine cannot package or stop a saved run'

# Static invocation check keeps state-changing commands out of this entry point.
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot 'tools\Capture-USB4DeepCompare.ps1'),[ref]$tokens,[ref]$errors)
Check ($errors.Count -eq 0) 'PS5.1 AST parses'
$commands=@($ast.FindAll({param($a) $a -is [Management.Automation.Language.CommandAst]},$true)|ForEach-Object {$_.GetCommandName()})
foreach($forbidden in @('New-ItemProperty','Set-ItemProperty','Remove-ItemProperty','Restart-Computer','Restart-DeepUcsi','Invoke-Usb4FirmwareQueries','Invoke-ProbeProcess','Set-NetAdapter','Initialize-Disk','Format-Volume','Invoke-Expression')){Check ($commands -notcontains $forbidden) 'No forbidden hardware/settings invocation'}
Write-Output ('Deep comparison validation passed: '+$script:deepChecks+' assertions. Hardware/ETW lifecycle mocked; native ACPI reads and file compression/splitting exercised. Private fixtures: '+$fixtureRoot)
