#requires -Version 5.1
Set-StrictMode -Version Latest

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Run this mode in a 64-bit Administrator Windows PowerShell console.'
    }
}

function Assert-ASUSModel {
    $model = [string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS').SystemProductName
    if ($model -notmatch '(^|\W|_)FA507XI($|\W|_)') { throw ('This toolkit is scoped to FA507XI; detected '+$model) }
    if (-not [Environment]::Is64BitProcess) { throw 'A 64-bit PowerShell process is required.' }
}

function Assert-ContainedPath {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Parent)
    $full = [IO.Path]::GetFullPath($Path)
    $base = [IO.Path]::GetFullPath($Parent).TrimEnd('\')+'\'
    if (-not $full.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escapes the intended test directory.' }
    return $full
}

function Assert-NoReparseAncestor {
    param([Parameter(Mandatory)][string]$Path)
    $cursor = [IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw ('Reparse points are not allowed: '+$cursor) }
            if (($item.Attributes -band ([IO.FileAttributes]::Compressed -bor [IO.FileAttributes]::Encrypted)) -ne 0) {
                throw ('Compressed/encrypted ancestors are not supported: '+$cursor)
            }
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
}

function ConvertTo-NativeArgument {
    param([AllowEmptyString()][string]$Value)
    if ($Value -match '[\r\n\x00]') { throw 'Invalid native argument.' }
    if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') { return $Value }
    $quoted = [regex]::Replace($Value,'(\\*)"','$1$1\"')
    $quoted = [regex]::Replace($quoted,'(\\+)$','$1$1')
    return '"'+$quoted+'"'
}

function Invoke-NativeChecked {
    param([Parameter(Mandatory)][string]$File,[string[]]$Arguments=@(),[int[]]$Allowed=@(0),[string]$LogPath)
    # No shell, elevation helper, command concatenation, or redirected secret output.
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = (($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) { throw ('Could not start '+[IO.Path]::GetFileName($File)) }
        $outTask = $process.StandardOutput.ReadToEndAsync()
        $errTask = $process.StandardError.ReadToEndAsync()
        while (-not $process.WaitForExit(1000)) { }
        $tasks = [Threading.Tasks.Task[]]@($outTask,$errTask)
        if (-not [Threading.Tasks.Task]::WaitAll($tasks,10000)) { throw 'Native output did not finish.' }
        $output = $outTask.Result+[Environment]::NewLine+$errTask.Result
        if ($LogPath) { [IO.File]::WriteAllText($LogPath,$output,(New-Object Text.UTF8Encoding($false))) }
        if ($Allowed -notcontains $process.ExitCode) { throw ('Native command failed ('+$process.ExitCode+'): '+[IO.Path]::GetFileName($File)+'. '+$output.Trim()) }
        return $output
    } finally { $process.Dispose() }
}

function Save-TestState {
    param([string]$Path,[object]$State)
    $temporary = $Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($temporary,($State | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Get-VhdCreationCommands {
    param([Parameter(Mandatory)][string]$Path)
    if($Path -notmatch '^[A-Za-z]:\\[A-Za-z0-9_ .\\-]+\.vhdx$'){throw 'Unsupported diskpart file path.'}
    return @(('create vdisk file="'+$Path+'" maximum=65536 type=expandable'),'exit')
}

function Assert-VirtualDiskTarget {
    param([Parameter(Mandatory)][string]$ImagePath,[Parameter(Mandatory)][int]$DiskNumber,[switch]$RequireRaw)
    $image = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop
    if (-not $image.Attached) { throw 'The expected VHDX is not attached.' }
    $disks = @($image | Get-Disk -ErrorAction Stop)
    if ($disks.Count -ne 1) { throw 'The VHDX must resolve to exactly one disk.' }
    $disk = $disks[0]
    if ($disk.Number -ne $DiskNumber -or [int]$disk.BusType -ne 15 -or $disk.IsBoot -or $disk.IsSystem) {
        throw 'Refusing a disk that is not the exact file-backed virtual test disk.'
    }
    if ([uint64]$disk.Size -ne [uint64](64GB)) { throw 'Unexpected virtual disk capacity.' }
    if ($RequireRaw -and [string]$disk.PartitionStyle -ne 'RAW') { throw 'Refusing a previously initialized disk.' }
    return $disk
}

function Get-BootEntryArguments {
    param([Parameter(Mandatory)][string]$Id,[Parameter(Mandatory)][string]$VhdPath)
    $parsed = [guid]::Empty
    if (-not [guid]::TryParse($Id.Trim('{}'),[ref]$parsed) -or $parsed -eq [guid]::Empty) { throw 'A newly allocated explicit boot GUID is required.' }
    $full = [IO.Path]::GetFullPath($VhdPath)
    if ($full -notmatch '^[A-Za-z]:\\.+\.vhdx$' -or $full -match '["\r\n]') { throw 'Invalid VHDX boot path.' }
    $device = 'vhd=['+$full.Substring(0,2)+']'+$full.Substring(2)
    return @(
        ,@('/create',$Id,'/d','USB4 test - temporary Windows','/application','OSLOADER')
        ,@('/set',$Id,'device',$device)
        ,@('/set',$Id,'osdevice',$device)
        ,@('/set',$Id,'path','\Windows\System32\winload.efi')
        ,@('/set',$Id,'systemroot','\Windows')
        ,@('/set',$Id,'inherit','{bootloadersettings}')
        ,@('/set',$Id,'detecthal','Yes')
        ,@('/displayorder',$Id,'/addlast')
    )
}

function Test-BootEntryOwnership {
    param([string]$Text,[string]$Id,[string]$VhdPath)
    $relative = ([IO.Path]::GetFullPath($VhdPath)).Substring(2)
    return ($Text.IndexOf($Id,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and
        $Text.Contains('USB4 test - temporary Windows') -and
        $Text.IndexOf($relative,[StringComparison]::OrdinalIgnoreCase) -ge 0)
}
