# Offline only: compile the codec, then supply byte fixtures. No native/device calls.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -Path (Join-Path $PSScriptRoot 'BillboardDescriptorProtocol.cs')
$script:checks = 0
function Assert-True([bool]$Value, [string]$Name) {
    if (-not $Value) { throw $Name }
    $script:checks++
}
function Assert-Rejected([scriptblock]$Action, [string]$Name) {
    $failed = $false
    try { & $Action | Out-Null } catch { $failed = $true }
    Assert-True $failed $Name
}
function Hex([string]$Text) {
    [byte[]]@($Text.Trim() -split '\s+' | ForEach-Object { [Convert]::ToByte($_,16) })
}
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
foreach ($name in @('asus','dell')) {
    [byte[]]$bos = Hex (Get-Content -LiteralPath (Join-Path $root "evidence/fixtures/deg2-$name-bos.hex") -Raw)
    $indices = [Usb4Research.BillboardDescriptorProtocol]::ValidateAdvertisedStrings($bos)
    Assert-True (($indices -join ',') -eq '7,8,9,10') "$name BOS indices"
}
[byte[]]$bad = $bos.Clone(); $bad[35] = 6
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ValidateAdvertisedStrings($bad) } 'Changed URL index'
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ValidateAdvertisedStrings([byte[]](5,15,5,0,1)) } 'Missing capability'
[byte[]]$q = [Usb4Research.BillboardDescriptorProtocol]::BuildStringRequest(4,7,0x409)
Assert-True ($q.Length -eq 267 -and $q[0] -eq 4 -and $q[6] -eq 7 -and $q[7] -eq 3 -and $q[8] -eq 9 -and $q[9] -eq 4 -and $q[10] -eq 255) 'Packed standard request'
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::BuildStringRequest(4,6,0x409) } 'Unadvertised index'
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::BuildStringRequest(0,7,0x409) } 'Port zero'
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::BuildStringRequest(4,0,0x409) } 'LANGID request must use language zero'
[byte[]]$lang = Hex '04 00 00 00 00 00 00 03 00 00 ff 00 06 03 09 04 11 04'
$languages = [Usb4Research.BillboardDescriptorProtocol]::ParseLanguages($lang,$lang.Length,4)
Assert-True (($languages -join ',') -eq '1033,1041') 'Multiple advertised languages'
$lang[16] = 9; $lang[17] = 4
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ParseLanguages($lang,$lang.Length,4) } 'Duplicate languages'
[byte[]]$text = Hex '04 00 00 00 00 00 07 03 09 04 ff 00 06 03 41 00 42 00'
Assert-True ([Usb4Research.BillboardDescriptorProtocol]::ParseText($text,$text.Length,4) -eq 'AB') 'UTF16 text'
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ParseText($text,$text.Length,3) } 'Wrong reply port'
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ParseText($text,$text.Length-1,4) } 'Odd reply length'
$text[15] = 0xd8
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ParseText($text,$text.Length,4) } 'Malformed surrogate pair'
[byte[]]$connection = New-Object byte[] 35
$connection[0]=4; $connection[4]=18; $connection[5]=1
$connection[12]=0x1f; $connection[13]=4; $connection[14]=2; $connection[15]=0xd0
$connection[16]=0; $connection[17]=0x82; $connection[25]=6; $connection[31]=1
Assert-True ([Usb4Research.BillboardDescriptorProtocol]::ValidateConnection($connection,35,4) -eq 6) 'Packed status offset31/address25'
$connection[24]=1
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ValidateConnection($connection,35,4) } 'Hub cannot substitute for Billboard'
$connection[24]=0; $connection[31]=0
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ValidateConnection($connection,35,4) } 'Disconnected port'
$connection[31]=1; $connection[12]=0x5c; $connection[13]=0x1d; $connection[14]=1; $connection[15]=0x58
Assert-Rejected { [Usb4Research.BillboardDescriptorProtocol]::ValidateConnection($connection,35,4) } 'Parent hub VID/PID cannot substitute'
Write-Output "Offline descriptor codec: $script:checks checks passed; no device access."
