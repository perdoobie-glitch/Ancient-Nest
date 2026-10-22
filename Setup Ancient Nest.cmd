@echo off
setlocal
cd /d "%~dp0"
echo Ancient Nest - First-time service setup
echo.
node -e "process.exit(Number(process.versions.node.split('.')[0]) >= 22 ? 0 : 1)" >nul 2>nul
if errorlevel 1 (
  echo Installing Node.js LTS using Windows Package Manager...
  winget install --id OpenJS.NodeJS.LTS --exact --source winget --accept-source-agreements --accept-package-agreements
  if errorlevel 1 goto :failed
  set "PATH=%ProgramFiles%\nodejs;%PATH%"
)
node "ancient-nest-accounts\scripts\setup-windows.mjs"
if errorlevel 1 goto :failed
echo.
echo Setup completed. You can close this window.
pause
exit /b 0
:failed
echo.
echo Setup stopped. Read the message above, then run this shortcut again.
pause
exit /b 1
