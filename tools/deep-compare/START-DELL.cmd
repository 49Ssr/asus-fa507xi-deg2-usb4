@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-USB4DeepCompare.ps1" -Mode Capture -Target Dell
set "captureCode=%errorlevel%"
echo.
echo Dell capture launcher finished with code %captureCode%. Keep the displayed result and laptop originals.
pause
exit /b %captureCode%
