@echo off
setlocal
cd /d "%~dp0"
set "NODE_OPTIONS=--dns-result-order=ipv4first"
echo V7 LOCAL TEST ONLY - not an Internet server. Keep this window open.
echo URL: http://127.0.0.1:18080 - guest identities, no official rank.
call npm.cmd ci
if errorlevel 1 goto failed
call npm.cmd run build
if errorlevel 1 goto failed
call node tests\local-server.mjs
:failed
pause
