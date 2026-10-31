@echo off
setlocal
set "CapturePS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if exist "%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe" set "CapturePS=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%CapturePS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Capture-DellDEG2Control.ps1" -Mode UndoUcsi
set "CaptureExit=%ERRORLEVEL%"
echo.
echo Undo exit code: %CaptureExit%
pause
exit /b %CaptureExit%
