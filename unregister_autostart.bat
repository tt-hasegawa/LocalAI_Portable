@echo off
setlocal enabledelayedexpansion
title LocalAI - AutoStart Unregistration

cd /d "%~dp0"
if exist "config.env.bat" call "config.env.bat"

echo ==============================================================================
echo [LocalAI] Unregister Windows Startup Task
echo ==============================================================================
echo.

rem Check administrative privileges
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Administrator privileges are required.
    echo Please right-click this file and select "Run as administrator".
    echo (kanrisha kengen de jikkou shite kudasai)
    echo.
    pause
    exit /b 1
)

set TASK_NAME=LocalAI_Portable

echo Removing startup task "%TASK_NAME%"...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "if (Get-ScheduledTask -TaskName '%TASK_NAME%' -ErrorAction SilentlyContinue) {" ^
    "    Unregister-ScheduledTask -TaskName '%TASK_NAME%' -Confirm:$false;" ^
    "    Write-Host '[SUCCESS] Task uninstalled from Task Scheduler.';" ^
    "} else {" ^
    "    Write-Host '[INFO] Task was not found in Task Scheduler.';" ^
    "}"

echo.
echo Stopping any running LocalAI services...
call "%~dp0stop.bat"

echo.
echo ==============================================================================
echo [SUCCESS] Auto-start task has been completely removed.
echo ==============================================================================
echo.
pause
