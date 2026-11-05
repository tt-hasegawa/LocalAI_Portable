@echo off
setlocal enabledelayedexpansion
title LocalAI - Stop Manager

cd /d "%~dp0"
if exist "config.env.bat" call "config.env.bat"

echo ==============================================================================
echo [LocalAI] Stopping running services...
echo ==============================================================================

rem --- 1. Terminate llama-server ---
echo [1/3] Terminating llama-server.exe...
taskkill /F /IM llama-server.exe /T >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo       llama-server was stopped successfully.
) else (
    echo       llama-server was not running.
)

rem --- 2. Terminate VS Code Web (Port %VSCODE_PORT%) ---
echo [2/3] Terminating VS Code Web (Port %VSCODE_PORT%)...
powershell -NoProfile -Command "$conns = Get-NetTCPConnection -LocalPort %VSCODE_PORT% -ErrorAction SilentlyContinue; if ($conns) { foreach ($c in $conns) { try { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue; Write-Host ('      Stopped process PID: ' + $c.OwningProcess) } catch {} } } else { Write-Host '      VS Code Web was not running.' }"

rem --- 3. Terminate HTTPS Reverse Proxy (Port %HTTPS_PORT%) ---
if "%HTTPS_PORT%"=="" goto SKIP_HTTPS
echo [3/3] Terminating HTTPS Reverse Proxy (Port %HTTPS_PORT%)...
powershell -NoProfile -Command "$conns = Get-NetTCPConnection -LocalPort %HTTPS_PORT% -ErrorAction SilentlyContinue; if ($conns) { foreach ($c in $conns) { try { Stop-Process -Id $c.OwningProcess -Force -ErrorAction SilentlyContinue; Write-Host ('      Stopped HTTPS Proxy PID: ' + $c.OwningProcess) } catch {} } } else { Write-Host '      HTTPS Proxy was not running.' }"
:SKIP_HTTPS

echo.
echo ==============================================================================
echo [SUCCESS] LocalAI services have been stopped.
echo ==============================================================================
ping 127.0.0.1 -n 3 >nul
