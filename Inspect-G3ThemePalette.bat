@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\python.exe" (
  echo [FAIL] Virtual environment not found. Run setup_windows.bat first.
  pause
  exit /b 1
)
set "HERO_PATH=%~1"
if not defined HERO_PATH (
  echo Paste full path to a game's backdrop.png or cover.png:
  set /p "HERO_PATH=Hero path: "
)
if not exist "%HERO_PATH%" (
  echo [FAIL] Image not found: %HERO_PATH%
  pause
  exit /b 1
)
".venv\Scripts\python.exe" -m g3_tools.theme_palette_inspector "%HERO_PATH%" --output "%TEMP%\g3_theme_palette_report.html"
if errorlevel 1 pause
