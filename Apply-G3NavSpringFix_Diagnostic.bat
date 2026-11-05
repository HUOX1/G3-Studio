@echo off
setlocal DisableDelayedExpansion
pushd "%~dp0"

set "INJECTOR=%~dp0Apply-G3NavSpringFix_Diagnostic.ps1"
if not exist "%INJECTOR%" (
  echo [FAIL] Required diagnostic injector was not found:
  echo        %INJECTOR%
  echo.
  echo Put Apply-G3NavSpringFix_Diagnostic.ps1 beside this BAT file.
  set "RESULT=2"
  goto :finish
)

echo [INFO] Using injector: Apply-G3NavSpringFix_Diagnostic.ps1
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INJECTOR%"
set "RESULT=%ERRORLEVEL%"

:finish
popd
echo.
if not "%RESULT%"=="0" (
  echo FAILED. Project source files were not force-reset or cleaned.
) else (
  echo Finished. Review the result above before launching Godot.
)
echo.
pause
exit /b %RESULT%
