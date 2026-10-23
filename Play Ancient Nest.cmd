@echo off
cd /d "%~dp0"
godot --path game
if errorlevel 1 pause
