#requires -Version 5.1
# Shared capture primitives only. Importing or running this file performs no capture.
$repo=Split-Path $PSScriptRoot -Parent
$privateRoot=Join-Path $repo 'local\UcsiMemoryProbe'
$toolRoot=Join-Path $privateRoot 'tooling'
$symbolRoot=Join-Path $privateRoot 'symbols'
$liveKd=Join-Path $toolRoot 'Livekd64.exe'

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

function Get-ConnectionProviderRows {
    # Audited against Microsoft's busiotools profile and this host's provider metadata.
    # USB transfer headers/payloads were excluded by the earlier 0xF861B mask.
    # Enabling a provider is a request, not evidence that the driver emitted events.
    return @(
        '{30E1D284-5D88-459C-83FD-6345B39B19EC} 0xFFFFFFFFFFFFFFFF 5'
        '{36DA592D-E43A-4E28-AF6F-4BC57C5A11E8} 0xFFFFFFFFFFFFFFFF 5'
        '{AC52AD17-CC01-4F85-8DF5-4DCE4333C99B} 0xFFFFFFFFFFFFFFFF 5'
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
        '{9C205A39-1250-487D-ABD7-E831C6290539} 0xFFFFFFFFFFFFFFFF 5'
        '{D07E8C3F-78FB-4C22-B77C-2203D00BFDF3} 0xFFFFFFFFFFFFFFFF 5'
        '{A3CDB002-FB1C-4C4B-922B-7535B2601C88} 0xFFFFFFFFFFFFFFFF 5'
        '{6FB6E467-9ED4-4B73-8C22-70B97E22C7D9} 0xFFFFFFFFFFFFFFFF 5'
        '{6E6CC2C5-8110-490E-9905-9F2ED700E455} 0xFFFFFFFFFFFFFFFF 5'
        '{9F7711DD-29AD-C1EE-1B1B-B52A0118A54C} 0xFFFFFFFFFFFFFFFF 5'
        '{BC6C9364-FC67-42C5-ACF7-ABED3B12ECC6} 0xFFFFFFFFFFFFFFFF 5'
        '{E6086B4D-AEFF-472B-BDA7-EEC662AFBF11} 0xFFFFFFFFFFFFFFFF 5'
        '{72CD9FF7-4AF8-4B89-AEDE-5F26FDA13567} 0xFFFFFFFFFFFFFFFF 5'
        '{C514638F-7723-485B-BCFC-96565D735D4A} 0xFFFFFFFFFFFFFFFF 5'
        '{331C3B3A-2005-44C2-AC5E-77220C37D6B4} 0xFFFFFFFFFFFFFFFF 5'
        '{96F4A050-7E31-453C-88BE-9634F4E02139} 0xFFFFFFFFFFFFFFFF 5'
        '{47711976-08C7-44EF-8FA2-082DA6A30A30} 0xFFFFFFFFFFFFFFFF 255'
        '{B3A0C2C8-83BB-4DDF-9F8D-4B22D3C38AD7} 0xFFFFFFFFFFFFFFFF 5'
    )
}

function Start-ConnectionTrace([string]$Directory) {
    $name='USB4_Ucsi_'+[guid]::NewGuid().ToString('N').Substring(0,12)
    $providerFile=Join-Path $Directory 'providers.txt';$etl=Join-Path $Directory 'connection.etl'
    [IO.File]::WriteAllLines($providerFile,(Get-ConnectionProviderRows),[Text.Encoding]::ASCII)
    $logman=Join-Path $env:SystemRoot 'System32\logman.exe'
    $output=& $logman create trace $name -ets -o $etl -pf $providerFile -f bin -max 1024 -bs 128 -nb 32 256 -ct perf -ft 1 2>&1
    $code=$LASTEXITCODE
    if($code -ne 0){
        try{[IO.File]::WriteAllText((Join-Path $Directory 'trace-start.txt'),($output -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}catch{Write-Warning ('Could not save ETW startup error: '+$_.Exception.Message)}
        throw ('ETW trace did not start; exit '+$code+': '+($output -join ' ')+'. Do not change the current cable connection.')
    }
    try{
        [IO.File]::WriteAllText((Join-Path $Directory 'trace-start.txt'),($output -join [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    }catch{
        # Start succeeded, but no ownership record can reach the caller. Stop here.
        $writeError=$_
        try{$null=& $logman stop $name -ets 2>&1;if($LASTEXITCODE -ne 0){Write-Warning ('Could not stop just-created session: logman stop '+$name+' -ets')}}catch{Write-Warning ('Check just-created session '+$name+': '+$_.Exception.Message)}
        throw $writeError
    }
    return [ordered]@{Name=$name;Etl='connection.etl';StartedUtc=[DateTime]::UtcNow.ToString('o');Stopped=$false;StopExitCode=$null;EventsLost=$null;FileMode='Sequential';MaxMiB=1024;ProviderCoverage='Requested; emitted coverage requires analysis'}
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
