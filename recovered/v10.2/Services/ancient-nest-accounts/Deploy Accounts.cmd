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
call npx.cmd wrangler login
if errorlevel 1 goto failed
call npx.cmd wrangler d1 migrations apply ancient-nest-accounts --remote
if errorlevel 1 goto failed
call npx.cmd wrangler deploy
if errorlevel 1 goto failed
echo Now configure account secrets and attach the matching custom domain.
pause
exit /b 0
:failed
echo Accounts deployment failed. Do not reset or delete a live D1 database.
pause
exit /b 1
