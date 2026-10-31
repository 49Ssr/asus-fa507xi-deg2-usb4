#requires -Version 5.1
<#
FA507XI examination only. Live mode uses Microsoft's signed LiveKD helper.
It discovers this session's ACPI mappings and attempts 48/64-byte virtual reads.
Connection mode adds fixed 4/12-byte symbol controls, PTE metadata and bounded ETW.
No arbitrary addresses, firmware/UCSI commands, repair mode, security or boot edits.
#>
[CmdletBinding()]
param(
    [ValidateSet('Preview','Prepare','Offline','Capture')][string]$Mode='Preview',
    [string]$DebuggerPath,
    [string]$SymbolCache,
    [string]$DumpPath,
    [ValidatePattern('^[a-zA-Z0-9_-]{1,40}$')][string]$Label='attached',
    [switch]$Connection,
    [ValidateRange(6,120)][int]$Samples=80,
    [ValidateRange(100,2000)][int]$IntervalMs=500,
    [ValidateRange(30,300)][int]$TimeoutSeconds=120
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$privateRoot=Join-Path $repo 'local\UcsiMemoryProbe'
$toolRoot=Join-Path $privateRoot 'tooling'
$symbolRoot=Join-Path $privateRoot 'symbols'
$liveKd=Join-Path $toolRoot 'Livekd64.exe'
$jsPath=Join-Path $PSScriptRoot 'UcsiMemory.js'

function Assert-LocalPath([string]$Path) {
    if([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[\r\n";]' -or $Path.StartsWith('\\')) {
        throw 'Use a local path without debugger command delimiters.'
    }
    return [IO.Path]::GetFullPath($Path)
}
function Assert-MicrosoftExecutable([string]$Path,[string]$ExpectedName) {
    $full=Assert-LocalPath $Path
    if([IO.Path]::GetFileName($full) -ine $ExpectedName -or -not(Test-Path -LiteralPath $full -PathType Leaf)) {
        throw ('Missing expected Microsoft executable: '+$ExpectedName)
    }
    $signature=Get-AuthenticodeSignature -LiteralPath $full
    if($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate -or
       $signature.SignerCertificate.Subject -notmatch '(?:^|,\s*)O=Microsoft Corporation(?:,|$)') {
        throw ('Microsoft signature validation failed: '+$ExpectedName)
    }
    return $full
}
function Quote-NativeArgument([string]$Value) {
    if($Value -match '[\r\n"]'){throw 'Invalid native argument.'}
    # Leave switches/simple names bare for LiveKD's legacy argument forwarding.
    if($Value.Length -gt 0 -and $Value -notmatch '\s'){return $Value}
    # Double final slashes before a required closing quote.
    return '"'+[regex]::Replace($Value,'(\\+)$','$1$1')+'"'
}
function Get-ImagePdbInfo([string]$Path) {
    $data=[IO.File]::ReadAllBytes($Path)
    function U16([int]$Offset) {
        if($Offset -lt 0 -or $Offset -gt $data.Length-2){throw 'Truncated PE image.'}
        [BitConverter]::ToUInt16($data,$Offset)
    }
    function U32([int]$Offset) {
        if($Offset -lt 0 -or $Offset -gt $data.Length-4){throw 'Truncated PE image.'}
        [BitConverter]::ToUInt32($data,$Offset)
    }
    if($data.Length -lt 64 -or (U16 0) -ne 0x5a4d){throw 'Invalid DOS header.'}
    $pe=[int](U32 60)
    if($pe -lt 64 -or $pe -gt $data.Length-264 -or (U32 $pe) -ne 0x4550){throw 'Invalid PE header.'}
    $sections=[int](U16 ($pe+6)); $optional=$pe+24; $optionalBytes=[int](U16 ($pe+20))
    if((U16 ($pe+4)) -ne 0x8664 -or (U16 $optional) -ne 0x20b -or $optionalBytes -lt 168 -or $sections -lt 1 -or $sections -gt 96){throw 'Expected bounded x64 PE image.'}
    $debugRva=U32 ($optional+160); $debugBytes=U32 ($optional+164)
    if($debugBytes -lt 28 -or $debugBytes -gt 65536 -or $debugBytes%28 -ne 0){throw 'Invalid PE debug directory.'}
    $table=$optional+$optionalBytes; $debugOffset=$null
    for($i=0;$i -lt $sections;$i++) {
        $entry=$table+$i*40; $rva=U32 ($entry+12); $rawBytes=U32 ($entry+16); $rawOffset=U32 ($entry+20)
        if([uint64]$debugRva -ge [uint64]$rva -and [uint64]$debugRva+[uint64]$debugBytes -le [uint64]$rva+[uint64]$rawBytes) {
            if($null -ne $debugOffset){throw 'Overlapping PE debug mappings.'}
            $debugOffset=[int64]$rawOffset+[int64]$debugRva-[int64]$rva
        }
    }
    if($null -eq $debugOffset -or $debugOffset -gt $data.Length-$debugBytes){throw 'Unmapped PE debug directory.'}
    $records=@(for($i=0;$i -lt $debugBytes;$i+=28){
        $entry=[int]$debugOffset+$i
        if((U32 ($entry+12)) -ne 2){continue}
        $length=[int64](U32 ($entry+16)); $raw=[int64](U32 ($entry+24))
        if($length -lt 25 -or $raw -lt 0 -or $length -gt 4096 -or $raw -gt $data.Length-$length){throw 'Invalid CodeView record.'}
        if([Text.Encoding]::ASCII.GetString($data,[int]$raw,4) -ne 'RSDS'){continue}
        $guidBytes=New-Object byte[] 16; [Array]::Copy($data,$raw+4,$guidBytes,0,16)
        $guid=New-Object Guid (,$guidBytes); $age=U32 ([int]$raw+20)
        $nameText=[Text.Encoding]::ASCII.GetString($data,[int]$raw+24,[int]$length-24)
        $nul=$nameText.IndexOf([char]0); if($nul -lt 0){throw 'Unterminated PDB name.'}
        $name=[IO.Path]::GetFileName($nameText.Substring(0,$nul))
        if($name -notmatch '^[a-zA-Z0-9_.-]+\.pdb$' -or $age -eq 0){throw 'Invalid PDB identity.'}
        [pscustomobject]@{Name=$name;Key=$guid.ToString('N').ToUpperInvariant()+$age.ToString('X');Image=$Path}
    })
    if($records.Count -ne 1){throw 'Expected exactly one RSDS record.'}
    return $records[0]
}
function Get-SymbolImages {
    return @((Join-Path $env:SystemRoot 'System32\ntoskrnl.exe'),(Join-Path $env:SystemRoot 'System32\drivers\acpi.sys'))
}
function Get-PdbKey([string]$Path) {
    if((Get-Item -LiteralPath $Path).Length -gt 128MB){throw 'PDB exceeds this probe cache limit.'}
    $pdbBytes=[IO.File]::ReadAllBytes($Path)
    if($pdbBytes.Length -lt 56 -or [Text.Encoding]::ASCII.GetString($pdbBytes,0,26) -ne ('Microsoft C/C++ MSF 7.00'+"`r`n")) {throw 'Expected an MSF 7 PDB.'}
    $block=[BitConverter]::ToUInt32($pdbBytes,32); $directoryBytes=[BitConverter]::ToUInt32($pdbBytes,44)
    $blockMap=[BitConverter]::ToUInt32($pdbBytes,52)
    if($block -lt 512 -or $block -gt 65536 -or ($block -band ($block-1)) -ne 0 -or $directoryBytes -lt 12 -or $directoryBytes -gt 16MB){throw 'Invalid PDB block directory.'}
    $directory=New-Object byte[] $directoryBytes
    $blocks=[int][Math]::Ceiling($directoryBytes/[double]$block)
    for($i=0;$i -lt $blocks;$i++){
        $mapOffset=[int64]$blockMap*$block+$i*4
        if($mapOffset -gt $pdbBytes.Length-4){throw 'Truncated PDB block map.'}
        $source=[int64]([BitConverter]::ToUInt32($pdbBytes,[int]$mapOffset))*$block
        $length=[int][Math]::Min($block,$directoryBytes-$i*$block)
        if($source -gt $pdbBytes.Length-$length){throw 'Invalid PDB directory block.'}
        [Array]::Copy($pdbBytes,$source,$directory,$i*$block,$length)
    }
    $streams=[BitConverter]::ToUInt32($directory,0)
    if($streams -lt 4 -or $streams -gt 100000 -or 4+[int64]$streams*4 -gt $directory.Length){throw 'Invalid PDB stream directory.'}
    $cursor=[int](4+$streams*4)
    $size0=[BitConverter]::ToUInt32($directory,4)
    if($size0 -ne [uint32]::MaxValue){$cursor+=4*[int][Math]::Ceiling($size0/[double]$block)}
    $size1=[BitConverter]::ToUInt32($directory,8)
    if($size1 -lt 28 -or $size1 -eq [uint32]::MaxValue -or $cursor -gt $directory.Length-4){throw 'Missing PDB identity stream.'}
    $infoOffset=[int64]([BitConverter]::ToUInt32($directory,$cursor))*$block
    if($infoOffset -gt $pdbBytes.Length-28){throw 'Truncated PDB identity stream.'}
    $guidBytes=New-Object byte[] 16;[Array]::Copy($pdbBytes,$infoOffset+12,$guidBytes,0,16)
    $guid=New-Object Guid (,$guidBytes)
    # Public-symbol postprocessing can advance stream 1's age. The DBI age binds
    # this native PDB to the executable; DbgEng also enforces matching via -ses.
    $dbiCursor=[int](4+$streams*4)
    for($i=0;$i -lt 3;$i++){
        $size=[BitConverter]::ToUInt32($directory,4+$i*4)
        if($size -ne [uint32]::MaxValue){$dbiCursor+=4*[int][Math]::Ceiling($size/[double]$block)}
    }
    if([BitConverter]::ToUInt32($directory,16) -lt 12 -or $dbiCursor -gt $directory.Length-4){throw 'Missing native PDB DBI stream.'}
    $dbiOffset=[int64]([BitConverter]::ToUInt32($directory,$dbiCursor))*$block
    if($dbiOffset -gt $pdbBytes.Length-12 -or [BitConverter]::ToUInt32($pdbBytes,[int]$dbiOffset) -ne [uint32]::MaxValue){throw 'Invalid PDB DBI header.'}
    $age=[BitConverter]::ToUInt32($pdbBytes,[int]$dbiOffset+8)
    return $guid.ToString('N').ToUpperInvariant()+$age.ToString('X')
}
function Ensure-ProbeTooling {
    New-Item -ItemType Directory -Path $toolRoot,$symbolRoot -Force | Out-Null
    if(-not(Test-Path -LiteralPath $liveKd)) {
        $zip=Join-Path $toolRoot 'LiveKD.zip'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://download.sysinternals.com/files/LiveKD.zip' -OutFile $zip -TimeoutSec 60
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive=[IO.Compression.ZipFile]::OpenRead($zip)
        try {
            foreach($name in @('Livekd64.exe','Eula.txt')) {
                $entries=@($archive.Entries|Where-Object {$_.FullName -ieq $name})
                if($entries.Count -ne 1 -or $entries[0].Length -gt 4MB){throw 'Unexpected LiveKD archive.'}
                [IO.Compression.ZipFileExtensions]::ExtractToFile($entries[0],(Join-Path $toolRoot $name),$false)
            }
        } finally {$archive.Dispose()}
    }
    $null=Assert-MicrosoftExecutable $liveKd 'Livekd64.exe'
    $records=@(foreach($image in Get-SymbolImages){
        $info=Get-ImagePdbInfo $image
        $destination=Join-Path $symbolRoot $info.Name
        $identityPath=$destination+'.identity'
        $valid=(Test-Path -LiteralPath $destination) -and (Test-Path -LiteralPath $identityPath)
        if($valid){$valid=([IO.File]::ReadAllText($identityPath) -eq $info.Key -and (Get-PdbKey $destination) -eq $info.Key)}
        if(-not $valid) {
            $candidate=$null
            $caches=@((Join-Path $repo 'local\KernelDump\symbols-flat'))
            if($SymbolCache){$caches=@((Assert-LocalPath $SymbolCache))+$caches}
            foreach($cache in $caches){
                $file=Join-Path $cache $info.Name
                if(Test-Path -LiteralPath $file){if((Get-PdbKey $file) -eq $info.Key){$candidate=$file;break}}
            }
            $temporary=$destination+'.download-'+[guid]::NewGuid().ToString('N')
            if($candidate){Copy-Item -LiteralPath $candidate -Destination $temporary}else{
                $uri='https://msdl.microsoft.com/download/symbols/'+$info.Name+'/'+$info.Key+'/'+$info.Name
                Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $temporary -TimeoutSec 90
            }
            if((Get-PdbKey $temporary) -ne $info.Key){throw 'PDB identity does not match the Windows image.'}
            Move-Item -LiteralPath $temporary -Destination $destination -Force
            [IO.File]::WriteAllText($identityPath,$info.Key,[Text.Encoding]::ASCII)
        }
        $info
    })
    [IO.File]::WriteAllText((Join-Path $privateRoot 'symbol-identities.json'),($records|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
}
function Assert-PreparedSymbols {
    foreach($image in Get-SymbolImages){
        $info=Get-ImagePdbInfo $image; $path=Join-Path $symbolRoot $info.Name
        if(-not(Test-Path -LiteralPath $path) -or -not(Test-Path -LiteralPath ($path+'.identity')) -or
           [IO.File]::ReadAllText($path+'.identity') -ne $info.Key -or (Get-PdbKey $path) -ne $info.Key){throw 'Current symbols are not prepared. Run -Mode Prepare.'}
    }
}
function Read-ProbeJson([string]$Text) {
    $matches=[regex]::Matches($Text,'(?s)UCSI_PROBE_JSON_BEGIN\s*[\r\n]+(.*?)\s*[\r\n]+UCSI_PROBE_JSON_END')
    if($matches.Count -ne 1){throw 'Debugger did not emit exactly one completed probe result. Inspect its private logs.'}
    $result=$matches[0].Groups[1].Value|ConvertFrom-Json
    if($result.schema -ne 1 -or $result.source -notin @('LiveKD','OfflineReplay')){throw 'Unexpected probe result schema.'}
    return $result
}
function Initialize-ProbeJobType {
    if('Usb4ProbeOwnedJob' -as [type]){return}
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public sealed class Usb4ProbeOwnedJob : IDisposable {
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long ProcessTime, JobTime; public uint Flags;
        public UIntPtr MinWorkingSet, MaxWorkingSet; public uint ActiveProcesses;
        public UIntPtr Affinity; public uint Priority, Scheduling;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters {
        public ulong ReadOps, WriteOps, OtherOps, ReadBytes, WriteBytes, OtherBytes;
    }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits Basic; public IoCounters Io;
        public UIntPtr ProcessMemory, JobMemory, PeakProcessMemory, PeakJobMemory;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    static extern IntPtr CreateJobObject(IntPtr attributes, string name);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref ExtendedLimits value, uint length);
    [DllImport("kernel32.dll", SetLastError=true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    private IntPtr handle;
    public Usb4ProbeOwnedJob() {
        handle=CreateJobObject(IntPtr.Zero,null);
        if(handle==IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
        var limits=new ExtendedLimits(); limits.Basic.Flags=0x2000; // KILL_ON_JOB_CLOSE
        if(!SetInformationJobObject(handle,9,ref limits,(uint)Marshal.SizeOf(typeof(ExtendedLimits)))) {
            int error=Marshal.GetLastWin32Error(); Dispose(); throw new Win32Exception(error);
        }
    }
    public void Attach(IntPtr process) {
        if(!AssignProcessToJobObject(handle,process)) throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public void Dispose() { if(handle!=IntPtr.Zero){CloseHandle(handle);handle=IntPtr.Zero;} }
}
'@
}
function Invoke-ProbeProcess([string]$Executable,[string[]]$Arguments,[string]$Directory,[int]$Timeout,[scriptblock]$OnTick=$null) {
    Initialize-ProbeJobType
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Executable; $info.Arguments=($Arguments|ForEach-Object {Quote-NativeArgument $_}) -join ' '
    $info.WorkingDirectory=$Directory; $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true; $info.RedirectStandardInput=$true
    $info.EnvironmentVariables['_NT_SYMBOL_PATH']=$symbolRoot
    $info.EnvironmentVariables['_NT_EXECUTABLE_IMAGE_PATH']=(Join-Path $env:SystemRoot 'System32')+';'+(Join-Path $env:SystemRoot 'System32\drivers')
    $info.EnvironmentVariables.Remove('_NT_DEBUG_LOG_FILE_APPEND')
    $info.EnvironmentVariables['_NT_DEBUG_LOG_FILE_OPEN']=Join-Path $Directory 'debugger.txt'
    $process=New-Object Diagnostics.Process; $process.StartInfo=$info
    $ownedJob=New-Object Usb4ProbeOwnedJob
    $watch=[Diagnostics.Stopwatch]::StartNew(); $timedOut=$false; $started=$false; $stdout=$null; $stderr=$null
    try {
        if(-not $process.Start()){throw 'Debugger launcher did not start.'}
        $started=$true
        $ownedJob.Attach($process.Handle)
        $process.StandardInput.Close()
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        while(-not $process.WaitForExit(1000)){
            if($watch.Elapsed.TotalSeconds -ge $Timeout){$timedOut=$true;break}
            if($null -ne $OnTick){& $OnTick}
            if([int]$watch.Elapsed.TotalSeconds%10 -eq 0){Write-Host ('Examining kernel view... '+[int]$watch.Elapsed.TotalSeconds+' seconds')}
        }
        if($timedOut){throw 'Probe timeout. Its owned launcher/debugger process tree will be stopped; helper unloading is not established by this wrapper.'}
        $process.WaitForExit()
        [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stdout.txt'),$stdout.GetAwaiter().GetResult(),(New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stderr.txt'),$stderr.GetAwaiter().GetResult(),(New-Object Text.UTF8Encoding($false)))
        return $process.ExitCode
    } finally {
        # Unnamed job holds only our launcher and descendants; no process enumeration.
        $ownedJob.Dispose()
        if($started -and -not $process.HasExited){
            # Assignment failure still leaves the process handle we created available.
            if(-not $process.WaitForExit(1000)){$process.Kill()}
            $launcherStopped=$process.WaitForExit(5000)
            [IO.File]::WriteAllText((Join-Path $Directory 'owned-process-cleanup.json'),
                ([ordered]@{LauncherPid=$process.Id;LauncherStopped=$launcherStopped;HelperUnloadingVerified=$false}|ConvertTo-Json),
                (New-Object Text.UTF8Encoding($false)))
            if(-not $launcherStopped){Write-Warning ('Owned launcher '+$process.Id+' is still running; inspect cleanup output.')}
        }
        if($timedOut -and $started -and -not(Test-Path -LiteralPath (Join-Path $Directory 'owned-process-cleanup.json'))){
            [IO.File]::WriteAllText((Join-Path $Directory 'owned-process-cleanup.json'),
                ([ordered]@{LauncherPid=$process.Id;LauncherStopped=$process.HasExited;HelperUnloadingVerified=$false}|ConvertTo-Json),
                (New-Object Text.UTF8Encoding($false)))
        }
        if($started){
            if($null -ne $stdout -and $stdout.IsCompleted){
                [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stdout.txt'),$stdout.GetAwaiter().GetResult(),(New-Object Text.UTF8Encoding($false)))
            }
            if($null -ne $stderr -and $stderr.IsCompleted){
                [IO.File]::WriteAllText((Join-Path $Directory 'launcher-stderr.txt'),$stderr.GetAwaiter().GetResult(),(New-Object Text.UTF8Encoding($false)))
            }
        }
        $process.Dispose()
    }
}

function Read-SharedProbeLog([string]$Path) {
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return ''}
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {
        if($stream.Length -gt 4MB){throw 'Unexpectedly large probe log.'}
        $reader=New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true)
        try {return $reader.ReadToEnd()} finally {$reader.Dispose()}
    } finally {$stream.Dispose()}
}
function Update-ConnectionPhase([hashtable]$State,[string]$LogText,[int]$Count,[int]$PauseMs,[datetime]$NowUtc=[DateTime]::UtcNow) {
    if($null -ne $State.ConnectPromptUtc){return 'Waiting'}
    if($null -eq $State.ReadyObservedUtc){
        if($LogText -match '(?m)^UCSI_CONNECTION_READY\r*$'){$State.ReadyObservedUtc=$NowUtc;return 'BaselineStarted'}
        return 'Waiting'
    }
    if(($NowUtc-[datetime]$State.ReadyObservedUtc).TotalSeconds -lt 5){return 'Waiting'}
    $samplesSeen=[regex]::Matches($LogText,'(?m)^UCSI_CONNECTION_SAMPLE \{"sequence":([0-9]+),')
    if($samplesSeen.Count -eq 0){throw 'Ready marker has no completed sample; leave DEG2 disconnected.'}
    $lastSample=[int]$samplesSeen[$samplesSeen.Count-1].Groups[1].Value
    if($lastSample -ge $Count -or ($Count-1-$lastSample)*$PauseMs -lt 10000){throw 'Insufficient sampling time remains to request a connection; leave DEG2 disconnected.'}
    $State.ConnectPromptUtc=$NowUtc.ToString('o');return 'ConnectNow'
}
function New-ProbeCommands([string]$Source,[string]$ScriptPath,[string]$ProviderPath,[bool]$Window,[int]$Count=80,[int]$PauseMs=500) {
    if($Source -notin @('LiveKD','OfflineReplay')){throw 'Invalid probe source.'}
    $ScriptPath=Assert-LocalPath $ScriptPath
    $ProviderPath=(Assert-LocalPath $ProviderPath).Replace('\','/')
    $lines=New-Object 'System.Collections.Generic.List[string]'
    foreach($line in @('.symopt- 0x40','.reload /f nt','.reload /f acpi.sys',('.load "'+$ProviderPath+'"'),('.scriptload "'+$ScriptPath+'"'))){$lines.Add($line)}
    if($Window){
        if($Count -lt 6 -or $Count -gt 120 -or $PauseMs -lt 100 -or $PauseMs -gt 2000 -or ($Count-1)*$PauseMs -gt 70000){throw 'Unsupported sampling window.'}
        $lines.Add('.cache 0');$lines.Add('.cache flushall')
        $lines.Add(('dx @$scriptContents.beginConnectionWindow("{0}",{1},{2})' -f $Source,$Count,$PauseMs))
        for($index=0;$index -lt $Count;$index++){
            $lines.Add(('dx @$scriptContents.sampleConnectionWindow({0})' -f $index))
            if($index -lt $Count-1){$lines.Add('.sleep 0n'+$PauseMs)}
        }
        $lines.Add('.cache');$lines.Add('dx @$scriptContents.endConnectionWindow()')
    }else{$lines.Add('dx @$scriptContents.probeFirmwareBuffers("'+$Source+'")')}
    $lines.Add('q');return $lines.ToArray()
}
function Get-ConnectionProviderRows {
    # Same providers/filtered USB keywords used by the completed connection traces.
    return @(
        '{30E1D284-5D88-459C-83FD-6345B39B19EC} 0x00000000000F861B 5'
        '{36DA592D-E43A-4E28-AF6F-4BC57C5A11E8} 0x00000000000F861B 5'
        '{AC52AD17-CC01-4F85-8DF5-4DCE4333C99B} 0x00000000000F861B 5'
        '{575BA31F-2B45-58C2-64FD-F5DC757B6137} 0xFFFFFFFFFFFFFFFF 5'
        '{AE795D36-2B11-5EFB-C7E0-5D552BC55D6C} 0xFFFFFFFFFFFFFFFF 5'
        '{505A6797-992E-43E6-B84E-235E41E3FD82} 0xFFFFFFFFFFFFFFFF 5'
        '{1B502FCB-68CD-4407-A59E-1EAF8AB9EA26} 0xFFFFFFFFFFFFFFFF 5'
        '{11434984-9AB6-57F0-FC34-DF79EA15C255} 0xFFFFFFFFFFFFFFFF 5'
        '{569D11AA-5068-5EE5-DA22-CE541C0B1481} 0xFFFFFFFFFFFFFFFF 5'
        '{C5964C90-1824-4835-857A-5E95F8AA33B2} 0xFFFFFFFFFFFFFFFF 5'
        '{EAD1EE75-4BFE-4E28-8AFA-E94B0A1BAF37} 0xFFFFFFFFFFFFFFFF 5'
        '{C500C63A-6EFE-433B-84A7-C0740D5DC97F} 0xFFFFFFFFFFFFFFFF 5'
        '{EDEF8E04-4E22-4A95-9D04-539EBD112A5E} 0xFFFFFFFFFFFFFFFF 5'
        '{9C205A39-1250-487D-ABD7-E831C6290539} 0x0000000000C9A000 5'
        '{D07E8C3F-78FB-4C22-B77C-2203D00BFDF3} 0xFFFFFFFFFFFFFFFF 5'
    )
}
function Start-ConnectionTrace([string]$Directory) {
    $name='USB4_Ucsi_'+[guid]::NewGuid().ToString('N').Substring(0,12)
    $providerFile=Join-Path $Directory 'providers.txt';$etl=Join-Path $Directory 'connection.etl'
    [IO.File]::WriteAllLines($providerFile,(Get-ConnectionProviderRows),[Text.Encoding]::ASCII)
    $logman=Join-Path $env:SystemRoot 'System32\logman.exe'
    $output=& $logman create trace $name -ets -o $etl -pf $providerFile -f bincirc -max 256 -bs 64 -nb 16 128 -ct perf -ft 1 2>&1
    $code=$LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $Directory 'trace-start.txt'),($output -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    if($code -ne 0){throw ('ETW trace did not start; exit '+$code+'. DEG2 should remain disconnected.')}
    return [ordered]@{Name=$name;Etl='connection.etl';StartedUtc=[DateTime]::UtcNow.ToString('o');Stopped=$false;StopExitCode=$null;EventsLost=$null}
}
function Stop-ConnectionTrace([object]$Trace,[string]$Directory) {
    $output=& (Join-Path $env:SystemRoot 'System32\logman.exe') stop $Trace.Name -ets 2>&1
    $Trace.StopExitCode=$LASTEXITCODE;$Trace.Stopped=($Trace.StopExitCode -eq 0)
    $Trace.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText((Join-Path $Directory 'trace-stop.txt'),($output -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    if(-not $Trace.Stopped){Write-Warning ('Own trace session did not stop: logman stop '+$Trace.Name+' -ets')}
}
function Save-ConnectionInventory([string]$Directory,[string]$Phase) {
    try {
        $rows=@(Get-PnpDevice -PresentOnly -ErrorAction Stop | Where-Object {
            $_.Class -eq 'Display' -or $_.InstanceId -like 'USB4\*' -or $_.InstanceId -match '^USB\\VID_(8087|041F)'
        } | Select-Object Status,Class,FriendlyName,InstanceId)
        $result=[ordered]@{Utc=[DateTime]::UtcNow.ToString('o');Devices=$rows;Error=$null}
    }catch{$result=[ordered]@{Utc=[DateTime]::UtcNow.ToString('o');Devices=@();Error=$_.Exception.Message}}
    [IO.File]::WriteAllText((Join-Path $Directory ('devices-'+$Phase+'.json')),($result|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
}

if($MyInvocation.InvocationName -eq '.'){return}
if($Mode -eq 'Preview') {
    Write-Output 'FA507XI examination: Prepare downloads signed LiveKD and matching kernel/ACPI public symbols.'
    Write-Output 'Capture requires Administrator, loads the LiveKD helper, discovers current UBTC mappings, and attempts 48/64-byte virtual reads.'
    Write-Output 'Add -Connection for before/during/after sampling and concurrent ETW. Disconnect first; connect only at the green prompt.'
    Write-Output 'The helper may be blocked or may not expose firmware pages. Missing/unreadable bytes are reported, not replaced with zeros.'
    Write-Output 'No repair, raw physical-memory access, AML evaluation, UCSI commands, security/boot/driver-binding changes or uploads.'
    exit 0
}
if(-not [Environment]::Is64BitProcess){throw 'Use 64-bit Windows PowerShell.'}
if(-not $DebuggerPath){$DebuggerPath=Join-Path $repo 'local\WinDbg\extracted\amd64\kd.exe'}
$DebuggerPath=Assert-MicrosoftExecutable $DebuggerPath 'kd.exe'
foreach($dependency in @('dbgeng.dll','winext\JsProvider.dll')){
    $path=Join-Path (Split-Path $DebuggerPath) $dependency
    $null=Assert-MicrosoftExecutable $path ([IO.Path]::GetFileName($dependency))
}
if($Mode -eq 'Prepare'){Ensure-ProbeTooling;Write-Output 'Tooling prepared. No kernel helper was loaded.';exit 0}
Assert-PreparedSymbols
if($Connection -and $Mode -notin @('Capture','Offline')){throw 'Connection sampling requires Capture or Offline.'}
if($Connection -and (($Samples-1)*$IntervalMs -gt 70000 -or $TimeoutSeconds*1000 -lt ($Samples-1)*$IntervalMs+30000)){throw 'Sampling window exceeds its bounded duration or leaves insufficient launcher time.'}
if($Connection -and $Mode -eq 'Capture' -and ($Samples-1)*$IntervalMs -lt 20000){throw 'Live connection sampling needs at least a twenty-second window.'}
$source='OfflineReplay'
if($Mode -eq 'Capture') {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $principal=New-Object Security.Principal.WindowsPrincipal($identity)
    if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Capture requires an Administrator PowerShell console for the signed LiveKD helper.'}
    $model=[string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS').SystemProductName
    if($model -notmatch '(?i)(^|[^a-z0-9])FA507XI([^a-z0-9]|$)'){throw 'This firmware mapping probe is scoped to FA507XI.'}
    $liveKd=Assert-MicrosoftExecutable $liveKd 'Livekd64.exe'
    if($DumpPath){throw 'Capture does not accept a dump path.'}
    $source='LiveKD'
} else {
    $DumpPath=Assert-LocalPath $DumpPath
    if(-not(Test-Path -LiteralPath $DumpPath -PathType Leaf)){throw 'Offline dump does not exist.'}
}
$run=Join-Path $privateRoot ('Runs\'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+$Label+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $run | Out-Null
$commandsPath=Join-Path $run 'probe.wds'; $debuggerLog=Join-Path $run 'debugger.txt'
$jsPath=Assert-LocalPath $jsPath
$provider=(Join-Path (Split-Path $DebuggerPath) 'winext\JsProvider.dll').Replace('\','/')
$commands=New-ProbeCommands $source $jsPath $provider ([bool]$Connection) $Samples $IntervalMs
[IO.File]::WriteAllLines($commandsPath,$commands,(New-Object Text.UTF8Encoding($false)))
# LiveKD changes KD's working directory. Use an absolute command file; move the
# absolute log, symbol and image paths into the child environment to limit options.
$common=@('-noshell','-ses','-cf',$commandsPath)
$status=[ordered]@{Schema=1;Mode=$Mode;Label=$Label;StartedUtc=[DateTime]::UtcNow.ToString('o');Result='NotCompleted';LiveViewBytesReturned=$false;Error=$null}
$trace=$null;$onTick=$null
$connectionState=@{ReadyObservedUtc=$null;ConnectPromptUtc=$null;CaptureStartedUtc=$null;InsertionTimeVerified=$false}
try {
    if($Connection -and $Mode -eq 'Capture'){
        Write-Host 'Disconnect only the DEG2 USB-C upstream cable from the ASUS. Leave the dock/PSU powered.' -ForegroundColor Cyan
        $null=Read-Host 'Press Enter when the cable is disconnected'
        Save-ConnectionInventory $run 'before'
        $trace=Start-ConnectionTrace $run
        $connectionState.CaptureStartedUtc=[DateTime]::UtcNow.ToString('o')
        $onTick={
            $liveText=Read-SharedProbeLog $debuggerLog
            $phase=Update-ConnectionPhase $connectionState $liveText $Samples $IntervalMs
            if($phase -eq 'BaselineStarted'){
                Write-Host 'Sampling is running. Keep DEG2 disconnected for the short baseline...' -ForegroundColor Cyan
            }
            if($phase -eq 'ConnectNow'){
                Write-Host 'CONNECT DEG2 NOW. Leave it connected until capture finishes; no further Enter press is needed.' -ForegroundColor Green
                [IO.File]::WriteAllText((Join-Path $run 'connection-markers.json'),($connectionState|ConvertTo-Json -Depth 3),(New-Object Text.UTF8Encoding($false)))
            }
        }
    }
    if($Mode -eq 'Capture'){
        Write-Host 'Starting signed LiveKD examination. This may temporarily load its kernel helper.' -ForegroundColor Cyan
        $code=Invoke-ProbeProcess $liveKd (@('-accepteula','-b','-k',$DebuggerPath)+$common) $run $TimeoutSeconds $onTick
    }else{$code=Invoke-ProbeProcess $DebuggerPath (@('-z',$DumpPath)+$common) $run $TimeoutSeconds}
    if(-not(Test-Path -LiteralPath $debuggerLog)){throw ('No debugger transcript; launcher exit '+$code+'. Inspect launcher output.')}
    $result=Read-ProbeJson ([IO.File]::ReadAllText($debuggerLog))
    if($result.source -ne $source){throw 'Capture source mismatch.'}
    if($Connection -and ($result.kind -ne 'ConnectionWindow' -or $result.samples.Count -ne $Samples)){throw 'Incomplete connection sampling result.'}
    [IO.File]::WriteAllText((Join-Path $run 'probe.json'),($result|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
    $readable=@($result.regions|Where-Object {$_.status -eq 'Readable'}).Count
    if($result.discovery -ne 'Validated'){$status.Result='DiscoveryFailed'}elseif($readable -eq 2){$status.Result='BothRegionsReadable'}elseif($readable -gt 0){$status.Result='OneRegionReadable'}else{$status.Result='RegionsUnavailable'}
    $status.LiveViewBytesReturned=($Mode -eq 'Capture' -and $readable -gt 0)
    $status.LauncherExitCode=$code
    if($Connection){
        $status.ConnectionWindow=$true;$status.SamplesCollected=$result.samples.Count
        $status.ChangingKernelClockObserved=$result.changingKernelClockObserved
        $status.DebuggerCacheDisabled=([IO.File]::ReadAllText($debuggerLog) -match 'cache is off')
        if($Mode -eq 'Capture' -and $null -eq $connectionState.ConnectPromptUtc){throw 'Sampling completed without a connect prompt; the connection transition was not tested.'}
    }
    Write-Host ('Result: '+$status.Result+'; source: '+$source)
    $result.regions|Select-Object name,status,expectedBytes|Format-Table -AutoSize
} catch {
    $status.Error=$_.Exception.Message; $status.Result='NotCompleted'; Write-Warning $status.Error
} finally {
    if($null -ne $trace){
        try{Stop-ConnectionTrace $trace $run}catch{$trace.StopError=$_.Exception.Message;Write-Warning ('ETW stop error for '+$trace.Name+': '+$_.Exception.Message)}
        [IO.File]::WriteAllText((Join-Path $run 'trace-status.json'),($trace|ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    }
    if($Connection){
        [IO.File]::WriteAllText((Join-Path $run 'connection-markers.json'),($connectionState|ConvertTo-Json -Depth 3),(New-Object Text.UTF8Encoding($false)))
        if($Mode -eq 'Capture'){Save-ConnectionInventory $run 'after'}
    }
    $status.FinishedUtc=[DateTime]::UtcNow.ToString('o')
    [IO.File]::WriteAllText((Join-Path $run 'status.json'),($status|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
    Write-Host ('Private results: '+$run)
}
if($status.Result -eq 'NotCompleted' -or $status.Result -eq 'DiscoveryFailed'){exit 1}
exit 0
