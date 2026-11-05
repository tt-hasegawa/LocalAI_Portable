@echo off
setlocal enabledelayedexpansion
title LocalAI Portable - Startup Manager

cd /d "%~dp0"

if not exist "config.env.bat" (
    echo [ERROR] config.env.bat not found.
    pause
    exit /b 1
)
call "config.env.bat"

echo ==============================================================================
echo        LocalAI Portable (VS Code Web + Continue + llama-server)
echo ==============================================================================
echo.

rem Create required directories if missing
if not exist "%LOGS_DIR%" mkdir "%LOGS_DIR%"
if not exist "%DATA_DIR%\profile" mkdir "%DATA_DIR%\profile"
if not exist "%DATA_DIR%\server-data" mkdir "%DATA_DIR%\server-data"
if not exist "%DATA_DIR%\server-data\extensions" mkdir "%DATA_DIR%\server-data\extensions"
if not exist "%DATA_DIR%\server-data\data\User" mkdir "%DATA_DIR%\server-data\data\User"
if not exist "%DATA_DIR%\cli-data" mkdir "%DATA_DIR%\cli-data"

rem --- Sync offline settings.json to server-data if needed ---
if exist "%DATA_DIR%\user-data\User\settings.json" (
    if not exist "%DATA_DIR%\server-data\data\User\settings.json" (
        copy /y "%DATA_DIR%\user-data\User\settings.json" "%DATA_DIR%\server-data\data\User\settings.json" >nul
    )
)

rem --- Redirect USERPROFILE to isolate environment ---
set USERPROFILE=%DATA_DIR%\profile
set APPDATA=%DATA_DIR%\profile\AppData\Roaming
set LOCALAPPDATA=%DATA_DIR%\profile\AppData\Local

rem --- Parse arguments (--no-pause and workspace folder) ---
set NO_PAUSE=0
set TARGET_FOLDER=
for %%a in (%*) do (
    if /i "%%~a"=="--no-pause" (
        set NO_PAUSE=1
    ) else (
        if "!TARGET_FOLDER!"=="" set TARGET_FOLDER=%%~a
    )
)
if "!TARGET_FOLDER!"=="" set TARGET_FOLDER=%DEFAULT_FOLDER%

rem --- Explicitly pin Continue global directory to portable folder ---
set CONTINUE_GLOBAL_DIR=%DATA_DIR%\profile\.continue

rem --- Synchronize port and context length into Continue config.yaml ---
if exist "%CONTINUE_GLOBAL_DIR%\config.yaml" (
    powershell -NoProfile -Command "$cfgPath = '%CONTINUE_GLOBAL_DIR%\config.yaml'; if (Test-Path $cfgPath) { $raw = [System.IO.File]::ReadAllText($cfgPath, [System.Text.Encoding]::UTF8); $updated = $raw -replace 'http://127\.0\.0\.1:\d+/v1', ('http://' + $env:LLAMA_HOST + ':' + $env:LLAMA_PORT + '/v1') -replace 'contextLength:\s*\d+', ('contextLength: ' + $env:CTX_SIZE); if ($raw -ne $updated) { [System.IO.File]::WriteAllText($cfgPath, $updated, [System.Text.Encoding]::UTF8) } }" >nul 2>nul
)

rem --- Add local DLL paths to system PATH for node.exe and extensions ---
set PATH=%ROOT_DIR%bin\python;%ROOT_DIR%bin\python\Scripts;%ROOT_DIR%bin\llama;%ROOT_DIR%bin\vscode;%PATH%

rem --- Verify required files ---
if not exist "%BIN_LLAMA%" (
    echo [ERROR] llama-server not found:
    echo         %BIN_LLAMA%
    echo Please place llama.cpp binaries inside bin\llama\ folder.
    echo Or run download_assets.ps1 on an online PC first.
    echo.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

if not exist "%MODELS_DIR%\%MODEL_NAME%" (
    echo [ERROR] LLM model file not found:
    echo         %MODELS_DIR%\%MODEL_NAME%
    echo Please place the GGUF model inside models\ folder.
    echo.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

if not exist "%BIN_VSCODE%" (
    echo [ERROR] VS Code not found:
    echo         %BIN_VSCODE%
    echo Please extract VS Code portable into bin\vscode\ folder.
    echo.
    if "%NO_PAUSE%"=="0" pause
    exit /b 1
)

rem --- Auto-detect CPU threads if set to 0 ---
set THREADS=%CPU_THREADS%
if "%THREADS%"=="0" (
    for /f "tokens=*" %%c in ('powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfCores -Sum).Sum" 2^>nul') do (
        set THREADS=%%c
    )
    if "!THREADS!"=="" (
        set THREADS=%NUMBER_OF_PROCESSORS%
    )
    if "!THREADS!"=="" (
        set THREADS=4
    )
)

rem --- Target workspace folder ---
set FOLDER_OPT=
if not "%TARGET_FOLDER%"=="" (
    if exist "%TARGET_FOLDER%" (
        set FOLDER_OPT=--default-folder "%TARGET_FOLDER%"
    )
)

echo [Configuration]
echo   - CPU Threads      : !THREADS!
echo   - Context Length   : %CTX_SIZE% tokens
echo   - Model File       : %MODEL_NAME%
echo   - llama-server     : http://%LLAMA_HOST%:%LLAMA_PORT%
echo   - VS Code Web Port : %VSCODE_PORT%
if exist "%BIN_PYTHON%" echo   - Portable Python  : Ready (Excel, CSV, Oracle, Postgres)
if "%ENABLE_HTTPS%"=="1" echo   - HTTPS Port       : %HTTPS_PORT% (SSL Reverse Proxy Active)
if not "%TARGET_FOLDER%"=="" echo   - Default Folder   : %TARGET_FOLDER%
echo ==============================================================================
echo.

rem --- Check if llama-server is already running ---
powershell -NoProfile -Command "$client = New-Object System.Net.Sockets.TcpClient; try { $client.Connect('%LLAMA_HOST%', %LLAMA_PORT%); Write-Output 'OPEN'; $client.Close() } catch { Write-Output 'CLOSED' }" 2>nul | findstr "OPEN" >nul
if %ERRORLEVEL% EQU 0 (
    echo [INFO] llama-server is already running on port %LLAMA_PORT%. Reusing instance.
    goto START_VSCODE
)

echo [1/2] Launching llama-server in minimized window...
start "LocalAI - llama-server (%MODEL_NAME%)" /min "%BIN_LLAMA%" -m "%MODELS_DIR%\%MODEL_NAME%" -c %CTX_SIZE% -t !THREADS! -b %BATCH_SIZE% --host %LLAMA_HOST% --port %LLAMA_PORT% -ngl 0

echo     Waiting for llama-server to load model (max 60 seconds)...
set WAIT_COUNT=0
:HEALTH_LOOP
ping 127.0.0.1 -n 3 >nul
set /a WAIT_COUNT+=2

powershell -NoProfile -Command "$client = New-Object System.Net.Sockets.TcpClient; try { $client.Connect('%LLAMA_HOST%', %LLAMA_PORT%); Write-Output 'OPEN'; $client.Close() } catch { Write-Output 'CLOSED' }" 2>nul | findstr "OPEN" >nul
if %ERRORLEVEL% EQU 0 (
    echo [SUCCESS] llama-server is ready after !WAIT_COUNT! seconds.
    goto START_VSCODE
)

if !WAIT_COUNT! GEQ 60 (
    echo.
    echo [WARNING] Waiting for llama-server timed out. Proceeding to launch VS Code anyway.
    goto START_VSCODE
)
goto HEALTH_LOOP

:START_VSCODE
rem --- Start HTTPS Reverse Proxy if enabled ---
if not "%ENABLE_HTTPS%"=="1" goto SKIP_START_HTTPS
echo.
echo [*] Preparing HTTPS Reverse Proxy (Port %HTTPS_PORT%)...
if not exist "%ROOT_DIR%cert\server.pfx" (
    if not exist "%ROOT_DIR%cert\server.crt" (
        powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT_DIR%tools\generate_cert.ps1"
    )
)
set BUNDLED_NODE=
for /d %%d in ("%DATA_DIR%\cli-data\serve-web\*") do if exist "%%d\node.exe" set BUNDLED_NODE=%%d\node.exe
if not "!BUNDLED_NODE!"=="" (
    start "LocalAI - HTTPS Proxy (%HTTPS_PORT%)" /min "!BUNDLED_NODE!" "%ROOT_DIR%tools\https_proxy.js"
    echo     [SUCCESS] HTTPS Reverse Proxy launched on port %HTTPS_PORT%.
) else (
    echo     [WARNING] node.exe not found in cli-data. HTTPS proxy could not be started.
)
:SKIP_START_HTTPS

echo.
echo ==============================================================================
echo [2/2] Starting VS Code Web (code serve-web)...
echo ==============================================================================
echo Access the IDE from your browser at:
if not "%ENABLE_HTTPS%"=="1" goto SHOW_HTTP_ONLY
echo   [HTTPS - Recommended]:
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        echo     -^> https://%%b:%HTTPS_PORT%/
    )
)
echo     -^> https://127.0.0.1:%HTTPS_PORT%/  (Server Local)
echo.
echo   [HTTP - Direct Port]:
:SHOW_HTTP_ONLY
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        echo   -^> http://%%b:%VSCODE_PORT%/
    )
)
echo   -^> http://127.0.0.1:%VSCODE_PORT%/  (Server Local)
echo.
if "%ENABLE_HTTPS%"=="1" echo [TIP] Project URL: https://127.0.0.1:%HTTPS_PORT%/?folder=C:/your/project/path
if not "%ENABLE_HTTPS%"=="1" echo [TIP] Project URL: http://127.0.0.1:%VSCODE_PORT%/?folder=C:/your/project/path
echo.
echo To stop, run stop.bat or press Ctrl+C in this window.
echo ==============================================================================
echo.

call "%BIN_VSCODE%" serve-web --host %VSCODE_HOST% --port %VSCODE_PORT% --without-connection-token --accept-server-license-terms --server-data-dir "%DATA_DIR%\server-data" --cli-data-dir "%DATA_DIR%\cli-data" --disable-telemetry %FOLDER_OPT%

if "%NO_PAUSE%"=="1" exit /b 0
pause
