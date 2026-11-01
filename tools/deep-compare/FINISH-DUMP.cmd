@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-USB4DeepCompare.ps1" -Mode FinishDump
set "finishCode=%errorlevel%"
echo.
echo Saved-run dump completion finished with code %finishCode%. Keep the original evidence.
pause
exit /b %finishCode%
