@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
echo Existing deployments: preserve the shared key and skip this step.
echo New connections: enter the SAME coordinator key configured on the account Worker.
echo Never enter Steam secrets here. Never share this key in chat.
call npx.cmd wrangler secret put COORDINATOR_API_KEY
pause
