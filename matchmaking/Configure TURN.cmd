@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
echo Paste TURN credentials only into the Wrangler secret prompts, not chat.
call npx.cmd wrangler secret put TURN_KEY_ID
if errorlevel 1 goto failed
call npx.cmd wrangler secret put TURN_KEY_API_TOKEN
if errorlevel 1 goto failed
echo TURN configuration complete. Do not share your key or token.
pause
exit /b 0
:failed
echo TURN configuration failed. Read the first error above.
pause
exit /b 1
