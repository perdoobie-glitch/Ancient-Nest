@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
node scripts\configure-secrets.mjs
if errorlevel 1 echo Secrets setup stopped. Read the explanation above; do not regenerate production keys.
pause
