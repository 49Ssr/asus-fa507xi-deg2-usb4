#requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Preview','Read')][string]$Mode = 'Preview')
$ErrorActionPreference = 'Stop'

# Exact BIOS314 HII variable layouts. Defaults describe the image, not current values.
$definitions = @(
    @{ Name='AMD_PBS_SETUP'; Guid='{A339D746-F678-49B3-9FC7-54CE0F9DF226}'; Size=0x500; Fields=@(
        @{Name='PD USB4 Control'; Offset=0x9c; Values=@{'0'='Disabled';'1'='Enabled'}},
        @{Name='PD Thunderbolt3 Alt Mode'; Offset=0x4d; Values=@{'0'='Enabled';'1'='Disabled'}},
        @{Name='UCSI Support'; Offset=0x14; Values=@{'0'='Disabled';'1'='Enabled'}},
        @{Name='UCSI tunnel location'; Offset=0x15; Values=@{'0'='EC RAM';'1'='MMIO'}},
        @{Name='USB4 ACPI dependency'; Offset=0x465; Values=@{'0'='Disabled';'1'='Enabled'}}
    )},
    @{ Name='AmdSetupPHX'; Guid='{3A997502-647A-4C82-998E-52EF9486A247}'; Size=0x67f; Fields=@(
        @{Name='USB4 pre-CM'; Offset=0x1a7; Values=@{'0'='Disabled';'1'='Enabled';'15'='Auto'}},
        @{Name='RT0 Router'; Offset=0x1a8; Values=@{'0'='Disabled';'1'='Enabled';'15'='Auto'}},
        @{Name='RT0 PCIe Tunnel'; Offset=0x1a9; Values=@{'0'='Disabled';'1'='Enabled';'15'='Auto'}},
        @{Name='RT1 Router'; Offset=0x1aa; Values=@{'0'='Disabled';'1'='Enabled';'15'='Auto'}},
        @{Name='RT1 PCIe Tunnel'; Offset=0x1ab; Values=@{'0'='Disabled';'1'='Enabled';'15'='Auto'}}
    )}
)
if ($Mode -eq 'Preview') {
    Write-Output 'READ ONLY: two named UEFI variables, ten BIOS314 settings. No setting write, driver, boot or EC/I2C/vendor command.'
    Write-Output 'Read mode requires ASUS FA507XI BIOS314 and an Administrator PowerShell. Variables may be unavailable at runtime.'
    Write-Output 'No current values have been read. This captures stored configuration, not live PD traffic or retimer state.'
    return
}
$system = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
if ($system.Manufacturer -notmatch 'ASUSTeK' -or $system.Model -notmatch '^ASUS TUF Gaming A15 FA507XI_FA507XI$|^FA507XI$' -or $bios.SMBIOSBIOSVersion -ne 'FA507XI.314') {
    throw 'This reader is qualified only for ASUS FA507XI BIOS FA507XI.314. Nothing read.'
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Read mode needs Administrator PowerShell for the documented UEFI read privilege. No firmware read attempted.'
}
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
public static class Usb4FirmwareReadOnly {
    [StructLayout(LayoutKind.Sequential)] struct LUID { public uint Low; public int High; }
    [StructLayout(LayoutKind.Sequential)] struct TP { public uint Count; public LUID Luid; public uint Attributes; }
    [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool CloseHandle(IntPtr handle);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);
    [DllImport("advapi32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool LookupPrivilegeValue(string system, string name, out LUID luid);
    [DllImport("advapi32.dll", SetLastError=true)] static extern bool AdjustTokenPrivileges(IntPtr token, bool disableAll, ref TP state, uint bytes, out TP previous, out uint required);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true, ExactSpelling=true)]
    static extern uint GetFirmwareEnvironmentVariableExW(string name, string guid, [Out] byte[] buffer, uint size, out uint attributes);
    public sealed class Result { public string Name; public uint Length; public uint Attributes; public int Error; public byte[] Data; }
    public static Result[] Read() {
        IntPtr token;
        if (!OpenProcessToken(GetCurrentProcess(), 0x28, out token)) throw new Win32Exception(Marshal.GetLastWin32Error());
        TP previous = new TP(); bool adjusted = false;
        try {
            LUID luid;
            if (!LookupPrivilegeValue(null, "SeSystemEnvironmentPrivilege", out luid)) throw new Win32Exception(Marshal.GetLastWin32Error());
            TP state = new TP { Count=1, Luid=luid, Attributes=2 }; uint required;
            if (!AdjustTokenPrivileges(token, false, ref state, (uint)Marshal.SizeOf(typeof(TP)), out previous, out required))
                throw new Win32Exception(Marshal.GetLastWin32Error());
            adjusted = true;
            int privilegeError = Marshal.GetLastWin32Error();
            if (privilegeError != 0) throw new Win32Exception(privilegeError);
            string[] names = { "AMD_PBS_SETUP", "AmdSetupPHX" };
            string[] guids = { "{A339D746-F678-49B3-9FC7-54CE0F9DF226}", "{3A997502-647A-4C82-998E-52EF9486A247}" };
            Result[] results = new Result[2];
            for (int i=0; i<2; i++) {
                byte[] data = new byte[65536]; uint attributes;
                uint length = GetFirmwareEnvironmentVariableExW(names[i], guids[i], data, (uint)data.Length, out attributes);
                int error = length == 0 ? Marshal.GetLastWin32Error() : 0;
                if (length > data.Length) throw new InvalidOperationException("Firmware returned invalid length");
                Array.Resize(ref data, (int)length);
                results[i] = new Result { Name=names[i], Length=length, Attributes=attributes, Error=error, Data=data };
            }
            return results;
        } finally {
            try {
                if (adjusted) {
                    TP ignored; uint required;
                    if (!AdjustTokenPrivileges(token, false, ref previous, (uint)Marshal.SizeOf(typeof(TP)), out ignored, out required))
                        throw new Win32Exception(Marshal.GetLastWin32Error(), "Could not restore process privilege state");
                    int restoreError = Marshal.GetLastWin32Error();
                    if (restoreError != 0) throw new Win32Exception(restoreError, "Could not restore process privilege state");
                }
            } finally { CloseHandle(token); }
        }
    }
}
'@
$root = Join-Path (Split-Path $PSScriptRoot -Parent) 'local\FirmwareSettings'
$run = Join-Path $root ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run -Force | Out-Null
$records = @()
try { $results = [Usb4FirmwareReadOnly]::Read() }
catch {
    [ordered]@{Utc=(Get-Date).ToUniversalTime().ToString('o');Status='ReadStopped';Error=$_.Exception.Message;Scope='No firmware setting changed; process privilege restoration attempted in finally'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $run 'error.private.json') -Encoding UTF8
    throw ('UEFI read stopped. Private record: ' + $run + '. ' + $_.Exception.Message)
}
foreach ($result in $results) {
    $definition = $definitions | Where-Object Name -eq $result.Name
    $record = [ordered]@{Name=$result.Name; Length=$result.Length; Attributes=$result.Attributes; Win32Error=$result.Error; Status='Unavailable'; Fields=@()}
    if ($result.Error -eq 0 -and $result.Length -gt 0) {
        [IO.File]::WriteAllBytes((Join-Path $run ($result.Name + '.private.bin')), $result.Data)
        if ($result.Length -eq $definition.Size) {
            $record.Status = 'StoredSettingsRead_NotLiveControllerState'
            foreach ($field in $definition.Fields) {
                $value = [int]$result.Data[$field.Offset]
                $meaning = $field.Values[[string]$value]
                if (-not $meaning) { $meaning = 'Unknown value; no interpretation' }
                $record.Fields += [ordered]@{Name=$field.Name; Value=$value; Meaning=$meaning}
                Write-Output ($field.Name + ': ' + $value + ' (' + $meaning + ')')
            }
        } else { $record.Status = 'UnexpectedLayout_NoDecode' }
    }
    $records += [pscustomobject]$record
}
[ordered]@{Utc=(Get-Date).ToUniversalTime().ToString('o'); Bios=$bios.SMBIOSBIOSVersion; Scope='Stored configuration only; no setting changed'; Variables=$records} |
    ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $run 'result.private.json') -Encoding UTF8
Write-Output ('Private result: ' + $run)
