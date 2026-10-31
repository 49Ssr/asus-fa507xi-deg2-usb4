#requires -Version 5.1
<# Parser/guard tests and WinDbg JavaScript tests on an existing offline dump.
   This test never starts LiveKD or loads a kernel helper. #>
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$DumpPath,[string]$DebuggerPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$probeTestRepo=Split-Path $PSScriptRoot
$probeSource=Join-Path $probeTestRepo 'tools\Invoke-UcsiMemoryProbe.ps1'
$probeTestDumpPath=$DumpPath; $probeTestDebuggerPath=$DebuggerPath
. $probeSource
$DumpPath=$probeTestDumpPath; $DebuggerPath=$probeTestDebuggerPath
if(-not $DebuggerPath){$DebuggerPath=Join-Path $probeTestRepo 'local\WinDbg\extracted\amd64\kd.exe'}
$DebuggerPath=Assert-MicrosoftExecutable $DebuggerPath 'kd.exe'
Assert-PreparedSymbols
$testOutput=Join-Path $privateRoot ('Tests\'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testOutput -Force | Out-Null
$checkCount=0
function Check([bool]$Condition,[string]$Description){if(-not $Condition){throw ('FAIL: '+$Description)};$script:checkCount++}
function MustThrow([scriptblock]$Action,[string]$Description){$threw=$false;try{& $Action|Out-Null}catch{$threw=$true};Check $threw $Description}
$parseErrors=$null;$tokens=$null
$null=[Management.Automation.Language.Parser]::ParseFile($probeSource,[ref]$tokens,[ref]$parseErrors)
Check ($parseErrors.Count -eq 0) 'PowerShell 5.1 syntax'
MustThrow {Assert-LocalPath '\\server\file'} 'Network path rejected'
MustThrow {Assert-LocalPath 'C:\fake;command'} 'Debugger command delimiter rejected'
MustThrow {Quote-NativeArgument ('a'+[char]34+'b')} 'Quote injection rejected'
Check ((Quote-NativeArgument '-ses') -eq '-ses' -and (Quote-NativeArgument 'probe.wds') -eq 'probe.wds') 'Simple LiveKD arguments remain unquoted'
Check ((Quote-NativeArgument 'C:\space dir\') -eq '"C:\space dir\\"') 'Trailing backslash quoted correctly'
$sample='{"schema":1,"source":"OfflineReplay"}'
$parsed=Read-ProbeJson ("UCSI_PROBE_JSON_BEGIN`r`r`n"+$sample+"`r`r`nUCSI_PROBE_JSON_END")
Check ($parsed.source -eq 'OfflineReplay') 'CR/CR/LF transcript accepted'
MustThrow {Read-ProbeJson 'no result'} 'Missing result rejected'
MustThrow {Read-ProbeJson ("UCSI_PROBE_JSON_BEGIN`n"+$sample+"`nUCSI_PROBE_JSON_END`nUCSI_PROBE_JSON_BEGIN`n"+$sample+"`nUCSI_PROBE_JSON_END")} 'Ambiguous results rejected'
foreach($image in Get-SymbolImages){
    $pdb=Get-ImagePdbInfo $image
    Check ($pdb.Key -match '^[A-F0-9]{33,40}$' -and $pdb.Name -like '*.pdb') 'Actual signed Windows PE PDB identity'
    Check ((Get-PdbKey (Join-Path $symbolRoot $pdb.Name)) -eq $pdb.Key) 'Actual Microsoft public PDB GUID and DBI age match image'
}
$badPe=Join-Path $testOutput 'bad-pe.bin';[IO.File]::WriteAllBytes($badPe,(New-Object byte[] 64))
MustThrow {Get-ImagePdbInfo $badPe} 'Invalid PE refused before symbol download'
MustThrow {Get-PdbKey $badPe} 'Invalid PDB refused before kernel inspection'
$testProviderPath=Join-Path (Split-Path $DebuggerPath) 'winext\JsProvider.dll'
MustThrow {New-ProbeCommands 'bad-source' $probeSource $testProviderPath $true 6 100} 'Unsupported window source rejected'
MustThrow {New-ProbeCommands 'OfflineReplay' $probeSource $testProviderPath $true 121 500} 'Oversized window rejected'
MustThrow {New-ProbeCommands 'OfflineReplay' $probeSource $testProviderPath $true 120 2000} 'Overlong window rejected'
Check (@(Get-ConnectionProviderRows).Count -eq 15) 'Established connection providers available without starting tracing'
$phaseClock=[DateTime]::UtcNow
$phaseState=@{ReadyObservedUtc=$null;ConnectPromptUtc=$null}
Check ((Update-ConnectionPhase $phaseState '' 80 500 $phaseClock) -eq 'Waiting') 'No plug prompt before debugger readiness'
$phaseLog="UCSI_CONNECTION_SAMPLE {`"sequence`":0,`"synthetic`":true}`r`r`nUCSI_CONNECTION_READY`r`r`n"
Check ((Update-ConnectionPhase $phaseState $phaseLog 80 500 $phaseClock) -eq 'BaselineStarted') 'Double-CR readiness starts baseline'
Check ((Update-ConnectionPhase $phaseState $phaseLog 80 500 $phaseClock.AddSeconds(4)) -eq 'Waiting') 'Disconnected baseline retained'
Check ((Update-ConnectionPhase $phaseState $phaseLog 80 500 $phaseClock.AddSeconds(5)) -eq 'ConnectNow') 'Connect prompt follows baseline while samples remain'
Check ((Update-ConnectionPhase $phaseState $phaseLog 80 500 $phaseClock.AddSeconds(6)) -eq 'Waiting') 'Connect prompt emitted once'
$lateState=@{ReadyObservedUtc=$phaseClock;ConnectPromptUtc=$null}
MustThrow {Update-ConnectionPhase $lateState $phaseLog 6 500 $phaseClock.AddSeconds(5)} 'Late readiness never requests a connection after the usable window'

# Synthetic namespace and memory-provider cases, executed by the actual WinDbg JS engine.
$jsTests=@'
function runProbeTests() {
    let passed = 0;
    function check(value, text) { if (!value) { throw new Error("FAIL: " + text); } passed++; }
    function rejects(fn, text) { let rejected = false; try { fn(); } catch (_) { rejected = true; } check(rejected, text); }
    // Deliberately synthetic addresses; these do not identify a real device or capture.
    const good = ["ACPI Name Space: \\_SB_.UBTC (synthetic)", "Device(UBTC)",
        "| Integer(_HID:Value=0x0000000000c06256[12608086])",
        "| OpRegion(PM08:RegionSpace=SystemMemory,Offset=ffff800000001000,Len=48)",
        "| OpRegion(EURM:RegionSpace=SystemMemory,Offset=ffff800000002000,Len=64)"];
    const regions = discoverUcsiRegions(good);
    check(regions.length === 2 && regions[0].expectedBytes === 48, "Valid names and sizes");
    rejects(function() { discoverUcsiRegions(good.slice(0, 4)); }, "Missing region");
    rejects(function() { discoverUcsiRegions(good.concat([good[3]])); }, "Duplicate region");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("c06256", "c06257");})); }, "Wrong HID");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("Len=48", "Len=4096");})); }, "Oversized region");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("SystemMemory", "SystemIO");})); }, "I/O region");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("ffff800000001000", "0000000090001000");})); }, "Physical address");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("ffff800000002000", "ffff800000001010");})); }, "Overlap");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("ffff800000001000", "fffffffffffffff0");})); }, "Address wrap");
    rejects(function() { discoverUcsiRegions(good.map(function(x) {return x.replace("ffff800000001000", "ffff8000fffffff0").replace("ffff800000002000", "ffff800100000000");})); }, "Cross-32-bit overlap");
    let calls = 0;
    const unavailable = examineRegions(regions, function() {calls++; throw new Error("missing captured page");});
    check(calls === 2 && unavailable.every(function(x) {return x.status === "Unavailable" && !x.rawHex;}), "Missing bytes never become zeros");
    const partial = examineRegions(regions, function() {return [1];});
    check(partial.every(function(x) {return x.status === "Unavailable";}), "Partial buffers refused");
    const badByte = examineRegions(regions, function(_, n) {return Array(n).fill(256);});
    check(badByte.every(function(x) {return x.status === "Unavailable";}), "Invalid byte values refused");
    const oversized = [{name:"PM08",mappedVirtualAddress:regions[0].mappedVirtualAddress,expectedBytes:4096},regions[1]];
    calls=0; rejects(function() {examineRegions(oversized,function(){calls++;});}, "Direct oversized provider read refused");
    check(calls === 0, "Guard runs before memory provider");
    const bytes=Array(48).fill(0);bytes[0]=0x20;bytes[1]=1;bytes[4]=6;bytes[5]=16;bytes[7]=0xc0;
    const decoded=decodeLegacyUcsi(bytes);
    check(decoded.version === "1.2.0" && decoded.cci.connectorChange === 3 && decoded.cci.dataLength === 16 && decoded.cci.commandCompleted === 1 && decoded.cci.error === 1, "Legacy CCI and unsigned high bits");
    check(decodeLegacyUcsi(Array(48).fill(255)).interpretation === "RawOnly", "FFFF version remains raw");
    check(decodeLegacyUcsi(Array(48).fill(0)).interpretation === "RawOnly", "Zero version remains raw");
    bytes[0]=0;bytes[1]=2;check(decodeLegacyUcsi(bytes).interpretation === "RawOnly", "Version 2 layout not guessed");
    const native=Array.from(host.memory.readMemoryValues(host.getModuleSymbolAddress("nt","NtBuildNumber"),4,1,false));
    check(native.length === 4 && native.every(function(x) {return typeof x === "number";}), "Actual debugger byte-provider type");
    rejects(function() {beginConnectionWindow("bad-source",6,100);}, "Window source rejected");
    rejects(function() {beginConnectionWindow("OfflineReplay",121,500);}, "Window count bounded");
    rejects(function() {beginConnectionWindow("OfflineReplay",120,2000);}, "Window duration bounded");
    rejects(function() {readKernelControl("NtBuildNumber",4096);}, "Control read length bounded");
    rejects(function() {readKernelControl("AnotherSymbol",4);}, "Control symbol bounded");
    beginConnectionWindow("OfflineReplay",6,100);
    rejects(function() {sampleConnectionWindow(2);}, "Out-of-order sample rejected before memory reads");
    rejects(function() {endConnectionWindow();}, "Incomplete window refused");
    const result={passed:passed};
    host.diagnostics.debugLog("UCSI_TEST_JSON_BEGIN\n"+JSON.stringify(result)+"\nUCSI_TEST_JSON_END\n");
    return result;
}
'@
$combined=Join-Path $testOutput 'ProbeTests.js'
[IO.File]::WriteAllText($combined,([IO.File]::ReadAllText((Join-Path $probeTestRepo 'tools\UcsiMemory.js'))+"`n"+$jsTests),(New-Object Text.UTF8Encoding($false)))
$commands=Join-Path $testOutput 'tests.wds';$log=Join-Path $testOutput 'debugger.txt'
$provider=(Join-Path (Split-Path $DebuggerPath) 'winext\JsProvider.dll').Replace('\','/')
$windowCommands=New-ProbeCommands 'OfflineReplay' $combined $provider $true 6 500
$windowCommands=@('dx @$scriptContents.runProbeTests()')+$windowCommands[5..($windowCommands.Count-1)]
$testCommands=@('.reload /f nt',('.load "'+$provider+'"'),('.scriptload "'+$combined+'"'))+$windowCommands
[IO.File]::WriteAllLines($commands,$testCommands,(New-Object Text.UTF8Encoding($false)))
# Emulate LiveKD's working-directory change while executing the real offline KD.
# Neither the command file nor output log lives in the debugger's changed directory.
$changedDirectory=Join-Path $testOutput 'different cwd'
New-Item -ItemType Directory -Path $changedDirectory | Out-Null
$launcher=Join-Path $testOutput 'ChangedDirectoryLauncher.ps1'
[IO.File]::WriteAllText($launcher,@'
param([string]$Kd,[string]$Dump,[string]$Commands)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath (Join-Path $PSScriptRoot 'different cwd')
[Environment]::CurrentDirectory=(Get-Location).Path
& $Kd -z $Dump -noshell -ses -cf $Commands
exit $LASTEXITCODE
'@,[Text.Encoding]::ASCII)
$testPowerShell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$callbackState=@{ReadySeenWhileRunning=$false}
$testTick={if((Read-SharedProbeLog $log) -match '(?m)^UCSI_CONNECTION_READY\r*$'){$callbackState.ReadySeenWhileRunning=$true}}
$code=Invoke-ProbeProcess $testPowerShell @('-NoProfile','-File',$launcher,'-Kd',$DebuggerPath,'-Dump',$DumpPath,'-Commands',$commands) $testOutput 60 $testTick
Check ($code -eq 0) 'Offline debugger completed'
$text=[IO.File]::ReadAllText($log)
$match=[regex]::Match($text,'(?s)UCSI_TEST_JSON_BEGIN\s*[\r\n]+(.*?)\s*[\r\n]+UCSI_TEST_JSON_END')
Check $match.Success 'JavaScript tests emitted a result'
$jsResult=$match.Groups[1].Value|ConvertFrom-Json
Check ($jsResult.passed -ge 20) 'JavaScript guard/decoder cases passed'
$window=Read-ProbeJson $text
Check ($window.kind -eq 'ConnectionWindow' -and $window.samples.Count -eq 6) 'Actual offline window completed all samples'
Check ($window.validatedSamples -eq 6 -and $window.regions[0].attemptedSamples -eq 6) 'Mappings rediscovered for each sample'
Check ($callbackState.ReadySeenWhileRunning) 'Ready marker readable from still-running debugger log'
Check ($text -match 'cache is off') 'Debugger cache disabled in actual KD'
Check (-not $window.changingKernelClockObserved) 'Offline clock is correctly not reported as changing'
Check (@($window.samples[0].controls | Where-Object {$_.symbol -eq 'NtBuildNumber' -and $_.status -eq 'Readable'}).Count -eq 1) 'Kernel control readable while firmware buffers are unavailable'
Check ($window.samples[0].pageTables.Count -eq 2 -and $window.samples[5].pageTables.Count -eq 2) 'Bounded mapping metadata captured at both ends'
$timeoutFolder=Join-Path $testOutput 'timeout';New-Item -ItemType Directory -Path $timeoutFolder|Out-Null
$sleeper=Join-Path $timeoutFolder 'sleeper.ps1'
[IO.File]::WriteAllText($sleeper,'Start-Sleep -Seconds 20',[Text.Encoding]::ASCII)
$timer=[Diagnostics.Stopwatch]::StartNew()
MustThrow {Invoke-ProbeProcess (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') @('-NoProfile','-File',$sleeper) $timeoutFolder 1} 'Owned test-process timeout stops execution'
$cleanup=Get-Content -LiteralPath (Join-Path $timeoutFolder 'owned-process-cleanup.json') -Raw|ConvertFrom-Json
Check ($timer.Elapsed.TotalSeconds -lt 10 -and $cleanup.LauncherStopped) 'Owned timeout process stopped without LiveKD'
Write-Output ('PowerShell checks: '+$checkCount+'; WinDbg JavaScript checks: '+$jsResult.passed+'. No LiveKD helper loaded.')
