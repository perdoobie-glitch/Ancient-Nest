@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
where node >nul 2>&1
if errorlevel 1 goto missingnode
node scripts\check-server.mjs
if errorlevel 1 echo Fix the FAIL above before searching.
pause

exit /b
:missingnode
echo Install Node.js LTS from https://nodejs.org then reopen this file.
pause
exit /b 1
