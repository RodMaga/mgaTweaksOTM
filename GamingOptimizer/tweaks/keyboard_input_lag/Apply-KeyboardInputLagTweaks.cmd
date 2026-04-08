@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-KeyboardInputLagTweaks.ps1"

endlocal
