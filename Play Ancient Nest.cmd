@echo off
setlocal
cd /d "%~dp0"
if exist "Windows Player\Ancient Nest.exe" (
  start "" "Windows Player\Ancient Nest.exe"
  exit /b 0
)
if exist "ancient-nest-accounts\dist\windows\Ancient Nest.exe" (
  start "" "ancient-nest-accounts\dist\windows\Ancient Nest.exe"
  exit /b 0
)
echo The Windows player build is missing. Extract the full Windows download first.
pause
exit /b 1
