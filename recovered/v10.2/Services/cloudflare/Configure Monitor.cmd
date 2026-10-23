@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
call node scripts\create-monitor-key.mjs
if errorlevel 1 goto failed
call npx.cmd wrangler secret put MONITOR_TOKEN < .secrets\monitor-key.txt
if errorlevel 1 goto failed
echo The key is installed. Copy it from the local Notepad window into the monitor.
echo Do not share it with players or include .secrets in uploads.
start "" notepad.exe ".secrets\monitor-key.txt"
pause
exit /b 0
:failed
echo Monitor key configuration failed.
pause
exit /b 1
