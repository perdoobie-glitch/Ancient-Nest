@echo off
setlocal
cd /d "%~dp0"
node "ancient-nest-accounts\scripts\voice-live-check.mjs"
echo.
pause
