# Exercise process supervision with harmless children; never call the USB reader.
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$entry=Join-Path (Split-Path $PSScriptRoot -Parent) 'Read-DEG2BillboardStrings.ps1'
$preview=. $entry
if($preview.Status -ne 'Prepared_NotHardwareTested') { throw 'Unexpected default mode' }
$exe=Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$fast=$null; $slow=$null
try {
    $fast=Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-Command','exit 0') -WindowStyle Hidden -PassThru
    if(-not (Wait-DEG2DescriptorWorker -Process $fast -TimeoutMilliseconds 5000)) { throw 'Completed worker was timed out' }
    $slow=Start-Process -FilePath $exe -ArgumentList @('-NoProfile','-Command','Start-Sleep -Seconds 30') -WindowStyle Hidden -PassThru
    if(Wait-DEG2DescriptorWorker -Process $slow -TimeoutMilliseconds 100) { throw 'Sleeping worker was accepted' }
    if(-not $slow.HasExited) { throw 'Owned sleeping child remains running' }
    Write-Output 'Completed-child and timed-out-child handling passed. No USB methods invoked.'
} finally {
    foreach($child in @($fast,$slow)) {
        if($null -ne $child) { if(-not $child.HasExited) { $child.Kill(); $child.WaitForExit(5000) | Out-Null }; $child.Dispose() }
    }
}
