@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
call node scripts\setup.mjs --guest
if errorlevel 1 goto failed
echo Next: Deploy Master.cmd, Configure TURN.cmd, Configure Monitor.cmd
pause
exit /b 0
:failed
echo Setup did not finish. Read the message above.
pause
exit /b 1
