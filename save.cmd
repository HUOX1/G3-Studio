@echo off
chcp 65001 >nul
title G3-Studio Save
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0save.ps1" %*
echo.
pause
