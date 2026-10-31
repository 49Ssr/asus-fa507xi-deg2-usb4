@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-USB4DeepCompare.ps1" -Mode Return
set "returnCode=%errorlevel%"
echo.
echo Return copy finished with code %returnCode%. Keep laptop originals until import is confirmed.
pause
exit /b %returnCode%
