@echo off
setlocal

set SCRIPT_DIR=%~dp0
set PS_SCRIPT=%SCRIPT_DIR%play_prepare_release.ps1

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*
set EXIT_CODE=%ERRORLEVEL%

if not "%EXIT_CODE%"=="0" (
  echo.
  echo FAILED with exit code %EXIT_CODE%.
  exit /b %EXIT_CODE%
)

echo.
echo DONE.
exit /b 0
