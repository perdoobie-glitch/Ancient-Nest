@echo off
setlocal
cd /d "%~dp0"
node "ancient-nest-accounts\scripts\integrate-game.mjs"
if errorlevel 1 echo Integration stopped. Read the message above; keep your existing game version.
pause
