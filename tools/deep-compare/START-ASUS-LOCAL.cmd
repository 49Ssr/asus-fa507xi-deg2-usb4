@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-ASUSLocalCompare.ps1" -Mode Capture -KitDirectory "%~dp0USB4-Deep-Compare-resumable"
echo.
echo Local ASUS run finished. Keep the displayed result and original evidence.
pause
