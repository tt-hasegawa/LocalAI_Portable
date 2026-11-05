@echo off
setlocal enabledelayedexpansion
title LocalAI - Extension Offline Installer

call "%~dp0config.env.bat"

echo ==============================================================================
echo [LocalAI] Offline Extension Installer
echo ==============================================================================

if not exist "%BIN_VSCODE%" (
    echo [ERROR] VS Code executable not found: %BIN_VSCODE%
    echo Please make sure VS Code is extracted in bin\vscode\ folder.
    pause
    exit /b 1
)

if not exist "%EXT_INSTALLER_DIR%" (
    echo [ERROR] Extension directory not found: %EXT_INSTALLER_DIR%
    pause
    exit /b 1
)

set USERPROFILE=%DATA_DIR%\profile
set APPDATA=%DATA_DIR%\profile\AppData\Roaming
set LOCALAPPDATA=%DATA_DIR%\profile\AppData\Local

if not exist "%DATA_DIR%\server-data\extensions" mkdir "%DATA_DIR%\server-data\extensions"
if not exist "%DATA_DIR%\extensions" mkdir "%DATA_DIR%\extensions"

echo Profile Directory   : %USERPROFILE%
echo Extensions Directory: %DATA_DIR%\server-data\extensions
echo.

set COUNT=0
for %%F in ("%EXT_INSTALLER_DIR%\*.vsix") do (
    set /a COUNT+=1
    echo ----------------------------------------------------------------------
    echo [!COUNT!] Installing to server-data: %%~nxF
    echo ----------------------------------------------------------------------
    call "%BIN_VSCODE%" --user-data-dir "%DATA_DIR%\user-data" --extensions-dir "%DATA_DIR%\server-data\extensions" --install-extension "%%F" --force
    call "%BIN_VSCODE%" --user-data-dir "%DATA_DIR%\user-data" --extensions-dir "%DATA_DIR%\extensions" --install-extension "%%F" --force >nul 2>nul
)

echo.
echo ==============================================================================
echo [SUCCESS] Extension installation finished. Total installed: !COUNT!
echo ==============================================================================
echo.
pause
