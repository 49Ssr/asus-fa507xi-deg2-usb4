#requires -Version 5.1
<#
Record a fresh-Windows connection test without restarting devices or changing
drivers, registry, boot policy, firmware, or networking. Raw output stays local.
#>
[CmdletBinding()]
param([switch]$Preview)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-XmlText {
    param([System.Xml.XmlNode]$Node,[string]$Path)
    $child=$Node.SelectSingleNode($Path)
    if($null -eq $child){return ''}
    return [string]$child.InnerText
}
function Read-DeviceRows {
    param([xml]$Inventory)
    return @(foreach($device in $Inventory.SelectNodes('//Device')) {
        [pscustomobject]@{
            Id=$device.GetAttribute('InstanceId')
            Name=Get-XmlText $device 'DeviceDescription'
            Class=Get-XmlText $device 'ClassName'
            Status=Get-XmlText $device 'Status'
            Driver=Get-XmlText $device 'DriverName'
            Service=Get-XmlText $device 'Service'
            Parent=Get-XmlText $device 'Parent'
            Version=Get-XmlText $device 'Properties/Property[@Key="DEVPKEY_Device_DriverVersion"]/Value'
            Problem=Get-XmlText $device 'Properties/Property[@Key="DEVPKEY_Device_ProblemCode"]/Value'
        }
    })
}
function Get-ExternalRouters {
    param([object[]]$Rows)
    return @($Rows|Where-Object {$_.Id -like 'USB4\*' -and $_.Id -notlike 'USB4\ROOT_DEVICE_ROUTER*' -and $_.Id -notlike 'USB4\VIRTUAL_POWER_PDO*'})
}
function Get-PreflightIssues {
    param([object[]]$Rows)
    $patterns=@(
        @{Name='AMD USB4 host';Pattern='^PCI\\VEN_1022&DEV_1668.*USB4_MS_CM\\';Count=1}
        @{Name='UCSI';Pattern='^ACPI\\USBC000\\';Count=1}
        @{Name='AMD I2C';Pattern='^ACPI\\AMDI0010\\';Count=3}
        @{Name='Parade SPB';Pattern='^ACPI\\PS8830(0A|0F|11|1A|1F|21)\\';Count=6}
        @{Name='Parade HID';Pattern='^ACPI\\PS8830(08|18)\\';Count=2}
    )
    return @(foreach($rule in $patterns) {
        $matches=@($Rows|Where-Object {$_.Id -match $rule.Pattern})
        if($matches.Count -ne $rule.Count){$rule.Name+': expected '+$rule.Count+', found '+$matches.Count}
        foreach($device in $matches){
            if($device.Status -ne 'Started' -or ($device.Problem -and $device.Problem -notmatch '^(0|0x0+)$')){
                $rule.Name+': '+$device.Name+'; status='+$device.Status+'; problem='+$device.Problem
            }
        }
    })
}
function Find-ResultBridge {
    param([object]$Config)
    $relative=[string]$Config.RepositoryRelativePath
    if([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)|:'){throw 'Invalid result bridge path.'}
    $found=@(foreach($drive in [IO.DriveInfo]::GetDrives()) {
        if(-not $drive.IsReady -or $drive.DriveType -ne 'Fixed'){continue}
        $repo=Join-Path $drive.RootDirectory.FullName $relative
        $marker=Join-Path $repo 'local\NativeBoot\bridge.json'
        if(Test-Path -LiteralPath $marker -PathType Leaf){
            $record=Get-Content -LiteralPath $marker -Raw|ConvertFrom-Json
            if($record.Schema -eq 1 -and $record.BridgeId -eq $Config.BridgeId){$repo}
        }
    })
    if($found.Count -ne 1){throw 'Could not resolve exactly one shared result directory. Results remain inside the test Windows.'}
    return $found[0]
}
if($MyInvocation.InvocationName -eq '.'){return}
if($Preview){Write-Output 'Read-only preview: captures PnP before/after one connection and a bounded USB/USB4 ETW trace. No device restart or configuration changes.';exit 0}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
if(-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Run this collector as Administrator.'}
$model=[string](Get-ItemProperty -LiteralPath 'HKLM:\HARDWARE\DESCRIPTION\System\BIOS').SystemProductName
if($model -notmatch 'FA507XI'){throw 'This baseline is scoped to FA507XI.'}
if(-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'bridge.json'))){throw 'Run the deployed collector inside the prepared test Windows.'}
$config=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bridge.json') -Raw|ConvertFrom-Json
$sharedRepo=Find-ResultBridge $config
$runName='FreshWindows-'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$resultRoot=Join-Path $PSScriptRoot ('Results\'+$runName)
New-Item -ItemType Directory -Path $resultRoot | Out-Null
$destination=Join-Path $sharedRepo ('local\Results\'+$runName)
# Verify that the shared host location is writable before starting a recording.
New-Item -ItemType Directory -Path $destination | Out-Null
$pnp=Join-Path $env:SystemRoot 'System32\pnputil.exe'
$logman=Join-Path $env:SystemRoot 'System32\logman.exe'
function Save-Inventory {
    param([string]$Name)
    $text=& $pnp /enum-devices /connected /services /relations /properties /format xml 2>&1
    if($LASTEXITCODE -ne 0){throw 'PnP inventory failed.'}
    $joined=$text -join [Environment]::NewLine
    [xml]$xml=$joined
    [IO.File]::WriteAllText((Join-Path $resultRoot ($Name+'.xml')),$joined,(New-Object Text.UTF8Encoding($false)))
    return @(Read-DeviceRows $xml)
}
Write-Host 'Disconnect the DEG2 USB-C cable from the ASUS before starting.' -ForegroundColor Cyan
$null=Read-Host 'Press Enter when disconnected'
$before=@(Save-Inventory 'before')
if(@(Get-ExternalRouters $before).Count -gt 0){throw 'Another external USB4 router is connected. Disconnect it and run the collector again.'}
$issues=@(Get-PreflightIssues $before)
if($issues.Count -gt 0){Write-Warning ('The baseline is incomplete; a negative result will be inconclusive: '+($issues -join '; '))}
$providers=@(
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
)
$providerFile=Join-Path $resultRoot 'providers.txt'
[IO.File]::WriteAllLines($providerFile,$providers,[Text.Encoding]::ASCII)
$session='Usb4Fresh-'+[guid]::NewGuid().ToString('N').Substring(0,12)
$etl=Join-Path $resultRoot 'connection.etl'
$started=$false
$stopped=$false
$after=@()
$captureError=''
try {
    $startOutput=& $logman create trace $session -o $etl -pf $providerFile -f bincirc -max 128 -ow -ets 2>&1
    $startCode=$LASTEXITCODE
    $startOutput|Set-Content -LiteralPath (Join-Path $resultRoot 'trace-start.txt') -Encoding UTF8
    if($startCode -ne 0){throw 'ETW recording did not start.'}
    $started=$true
    Write-Host 'RECORDING. Connect the DEG2 to the ASUS USB4 port now.' -ForegroundColor Green
    $null=Read-Host 'After the notification appears, press Enter (or wait about 20 seconds if none appears)'
    Write-Host 'Recording another 15 seconds...'
    Start-Sleep -Seconds 15
    $after=@(Save-Inventory 'after')
} catch {
    $captureError=$_.Exception.Message
    $captureError|Set-Content -LiteralPath (Join-Path $resultRoot 'capture-error.txt') -Encoding UTF8
} finally {
    if($started){
        $stopOutput=& $logman stop $session -ets 2>&1
        $stopped=($LASTEXITCODE -eq 0)
        $stopOutput|Set-Content -LiteralPath (Join-Path $resultRoot 'trace-stop.txt') -Encoding UTF8
    }
}
$external=@(Get-ExternalRouters $after)
$newDisplays=@($after|Where-Object {$_.Class -eq 'Display' -and @($before.Id) -notcontains $_.Id})
$os=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$summary=[pscustomobject]@{
    Schema=1; Model='FA507XI'; CapturedUtc=[DateTime]::UtcNow.ToString('o')
    WindowsBuild=([string]$os.CurrentBuild+'.'+[string]$os.UBR)
    PreflightIssues=$issues; TraceStopped=$stopped; CaptureError=$captureError
    ExternalRouters=$external; NewDisplayAdapters=$newDisplays
    UsbFallback=@($after|Where-Object {$_.Id -match '^USB\\VID_(041F&PID_D002|8087&PID_5787)'})
    Interpretation=$(if($external.Count -gt 0){'An external USB4 router enumerated. Check the attached PCIe devices and compare with original Windows.'}elseif($issues.Count -gt 0 -or -not $stopped -or $captureError){'Incomplete baseline/capture: no negative conclusion is justified.'}else{'No external USB4 router enumerated on this fresh-Windows baseline. Firmware/hardware/cable interoperability is a stronger lead, not a proven diagnosis.'})
}
$summary|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $resultRoot 'summary.json') -Encoding UTF8
Get-ChildItem -LiteralPath $resultRoot -File|Copy-Item -Destination $destination
Write-Host $summary.Interpretation -ForegroundColor Cyan
Write-Host ('Saved results to the shared project: '+$destination)
Write-Host 'Restart and select your original Windows. The original local assistant session does not run in this test installation.'
