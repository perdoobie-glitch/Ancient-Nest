@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
call node scripts\setup.mjs
if errorlevel 1 goto failed
echo Next: Deploy Accounts.cmd, Configure Account Secrets.cmd, then attach your custom domain.
pause
exit /b 0
:failed
pause
exit /b 1
