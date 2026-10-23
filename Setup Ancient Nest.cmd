@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
call npm ci --prefix ancient-nest-accounts --ignore-scripts
if errorlevel 1 goto failed
call npm ci --prefix matchmaking
if errorlevel 1 goto failed
python ancient-nest-accounts\scripts\install-discord-sdk.py
if errorlevel 1 goto failed
python scripts\prepare-game.py
if errorlevel 1 goto failed
godot --headless --editor --path game --quit-after 100
if errorlevel 1 goto failed
echo Setup complete. Run Play Ancient Nest.cmd. Cloudflare deployment is separate.
pause
exit /b 0
:failed
echo Setup stopped. Read the error above and PC_CODEX_HANDOFF.md.
pause
exit /b 1
