@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-USB4DeepCompare.ps1" -Mode StopTrace
set "stopCode=%errorlevel%"
echo.
echo Owned trace cleanup finished with code %stopCode%.
pause
exit /b %stopCode%
