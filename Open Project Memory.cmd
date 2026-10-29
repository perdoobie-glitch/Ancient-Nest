@echo off
cd /d "%~dp0"
python ancient_memory.py gui
if errorlevel 1 pause
