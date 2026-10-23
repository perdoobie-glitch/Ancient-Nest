@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
call node scripts\setup.mjs --production
if errorlevel 1 goto failed
echo Next: configure accounts and shared stats key, then Deploy Master.cmd
pause
exit /b 0
:failed
pause
exit /b 1
