@echo off
title USB4 firmware settings - read only
echo Right-click this file and choose Run as administrator.
echo This reads stored BIOS settings. It does not change settings or require a boot.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Read-USB4FirmwareSettings.ps1" -Mode Read
echo.
echo Finished or stopped. Keep the result and return to the chat.
pause
