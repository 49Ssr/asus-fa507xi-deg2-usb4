@echo off
setlocal
set "CapturePS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "CapturePS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%CapturePS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-DellDEG2Control.ps1" -Mode Run
set "CaptureExit=%ERRORLEVEL%"
echo.
echo Collector exit code: %CaptureExit%
echo Keep the Results folder on this USB drive.
echo If cleanup could not finish, disconnect DEG2 and run UNDO.cmd as administrator on this same Dell.
pause
exit /b %CaptureExit%
