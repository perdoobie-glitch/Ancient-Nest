@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
call npm.cmd ci
if errorlevel 1 goto failed
call npm.cmd run typecheck
if errorlevel 1 goto failed
call npm.cmd run build
if errorlevel 1 goto failed
call npm.cmd test
if errorlevel 1 goto failed
call npx.cmd wrangler login
if errorlevel 1 goto failed
call npx.cmd wrangler deploy
if errorlevel 1 goto failed
echo Save the HTTPS workers.dev URL above. Game connection uses wss:// plus /v1/matchmaking
pause
exit /b 0
:failed
echo Deployment failed. Keep this window open and read the first error.
pause
exit /b 1
