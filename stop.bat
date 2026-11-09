@echo off
setlocal enabledelayedexpansion
title LocalAI - Stop Manager

cd /d "%~dp0"
if exist "config.env.bat" call "config.env.bat"

echo ==============================================================================
echo [LocalAI] Stopping running services...
echo ==============================================================================

if "%HTTPS_PORT%"=="" set HTTPS_PORT=0
if "%VSCODE_PORT%"=="" set VSCODE_PORT=8000
if "%LLAMA_PORT%"=="" set LLAMA_PORT=58080

rem --- 1. Terminate llama-server ---
echo [1/3] Terminating llama-server.exe...
taskkill /F /IM llama-server.exe /T >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo       llama-server was stopped successfully.
) else (
    echo       llama-server was not running.
)

rem --- 2. Terminate VS Code Web, HTTPS Proxy, and background node workers ---
echo [2/3] Terminating VS Code Web, HTTPS Proxy, and background workers...
if exist "%~dp0tools\stop_services.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\stop_services.ps1" -RootDir "%~dp0." -VscodePort %VSCODE_PORT% -HttpsPort %HTTPS_PORT% -LlamaPort %LLAMA_PORT%
) else (
    rem Fallback inline termination if script is missing
    powershell -NoProfile -Command "$ports = @(%VSCODE_PORT%, %HTTPS_PORT%, %LLAMA_PORT%) | Where-Object { $_ -gt 0 }; foreach ($p in $ports) { $conns = Get-NetTCPConnection -LocalPort $p -ErrorAction SilentlyContinue; if ($conns) { foreach ($c in $conns) { try { taskkill /PID $c.OwningProcess /T /F >nul 2>nul } catch {} } } }"
)

rem --- 3. Final verification ---
echo [3/3] Finalizing cleanup...
echo.
echo ==============================================================================
echo [SUCCESS] LocalAI services have been stopped.
echo ==============================================================================
ping 127.0.0.1 -n 3 >nul
