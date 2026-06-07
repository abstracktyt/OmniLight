@echo off
title OmniLight - GitHub Setup

set "SCRIPT=%~dp0push_to_github.ps1"

if not exist "%SCRIPT%" (
    echo.
    echo ERROR: push_to_github.ps1 not found in:
    echo %~dp0
    echo.
    echo Make sure both files are in the same folder:
    echo   push_to_github.bat
    echo   push_to_github.ps1
    echo.
    pause
    exit /b 1
)

echo.
echo  OmniLight - GitHub Setup
echo  ========================
echo.
echo Starting PowerShell script...
echo.

powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"

pause
