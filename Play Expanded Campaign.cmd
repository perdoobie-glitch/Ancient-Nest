@echo off
setlocal
cd /d "%~dp0"
if exist "%~dp0builds\windows-relief\Ancient Nest - Nine Missions.exe" (
  start "" "%~dp0builds\windows-relief\Ancient Nest - Nine Missions.exe" -- --campaign-menu
  exit /b
)
if exist "%~dp0builds\windows\Ancient Nest - Nine Missions.exe" (
  start "" "%~dp0builds\windows\Ancient Nest - Nine Missions.exe" -- --campaign-menu
  exit /b
)
call "%~dp0Play Ancient Nest Campaign.cmd"
