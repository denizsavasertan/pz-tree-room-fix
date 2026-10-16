@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Manage-TreeFix.ps1" -Action Install
pause
