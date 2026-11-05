@echo off
setlocal enabledelayedexpansion
title LocalAI - AutoStart Registration

cd /d "%~dp0"
if exist "config.env.bat" call "config.env.bat"

echo ==============================================================================
echo [LocalAI] Register Windows Startup Task (Task Scheduler)
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
set SCRIPT_DIR=%~dp0
rem Remove trailing backslash if present
if "%SCRIPT_DIR:~-1%"=="\" set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
set START_BAT=%SCRIPT_DIR%\start.bat

echo Setting up background startup task...
echo   - Task Name         : %TASK_NAME%
echo   - Target Script     : %START_BAT%
echo   - Working Directory : %SCRIPT_DIR%
echo   - Trigger           : At System Startup (Boot)
echo   - Account           : SYSTEM (Runs without user login)
echo   - Execution Limit   : Unlimited (Continuous background service)
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$taskName = '%TASK_NAME%';" ^
    "$workingDir = '%SCRIPT_DIR%';" ^
    "$startBat = '%START_BAT%';" ^
    "$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/c `\"' + $startBat + '`\" --no-pause') -WorkingDirectory $workingDir;" ^
    "$trigger = New-ScheduledTaskTrigger -AtStartup;" ^
    "$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([System.TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1);" ^
    "$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest;" ^
    "Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null;" ^
    "Write-Host '[SUCCESS] Task has been registered in Windows Task Scheduler.'"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Failed to register task. Return code: %ERRORLEVEL%
    pause
    exit /b 1
)

echo.
echo ==============================================================================
echo [SUCCESS] Auto-start task has been registered successfully!
echo ==============================================================================
echo.
echo - LocalAI will automatically start in the background when the OS boots.
echo - No Windows user login is required.
echo - You can manage it from Windows 'Task Scheduler' (taskschd.msc).
echo - To unregister: Run 'unregister_autostart.bat' as administrator.
echo.

set /p START_NOW="Do you want to start LocalAI right now? (Y/N, default: Y): "
if /i "%START_NOW%"=="" set START_NOW=Y
if /i "%START_NOW%"=="Y" (
    echo.
    echo Starting %TASK_NAME% via Task Scheduler...
    schtasks /run /tn "%TASK_NAME%" >nul 2>&1
    echo LocalAI services are starting in the background.
    echo Access the IDE in a few seconds at:
    echo   -> http://localhost:%VSCODE_PORT%/
)

echo.
echo Press any key to exit.
pause >nul
