@echo off
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Revert-KeyboardInputLagTweaks.ps1"

endlocal
