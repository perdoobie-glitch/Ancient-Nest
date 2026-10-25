@echo off
setlocal
cd /d "%~dp0"
set "CAMPAIGN_GODOT=%GODOT_BIN%"
if not defined CAMPAIGN_GODOT if exist "%USERPROFILE%\Documents\AncientNest-Unified-Setup-e0bf594\Tools\Godot-4.6.3\Godot_v4.6.3-stable_win64.exe" set "CAMPAIGN_GODOT=%USERPROFILE%\Documents\AncientNest-Unified-Setup-e0bf594\Tools\Godot-4.6.3\Godot_v4.6.3-stable_win64.exe"
if not defined CAMPAIGN_GODOT set "CAMPAIGN_GODOT=godot"
"%CAMPAIGN_GODOT%" --path "%~dp0game" -- --campaign-menu
if errorlevel 1 pause
