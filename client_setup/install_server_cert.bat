@echo off
setlocal enabledelayedexpansion
title LocalAI - Install Server SSL Certificate

echo ==============================================================================
echo   LocalAI Portable - SSLサーバー証明書 インストールツール (クライアントPC用)
echo ==============================================================================
echo.
echo サーバー側で自己署名SSL証明書（HTTPSモード）を利用している場合、
echo このスクリプトを実行することで、クライアントPCの「信頼されたルート証明機関」に
echo サーバー証明書を登録し、ブラウザのセキュリティ警告（赤文字）を解消します。
echo.

rem Check administrative privileges
net session >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] 証明書のインストールには管理者権限が必要です。
    echo 本ファイルを右クリックし、「管理者として実行」を選択してください。
    echo.
    pause
    exit /b 1
)

set CER_FILE=%~dp0LocalAI_Server.cer
if not exist "%CER_FILE%" (
    set CER_FILE=%~dp0..\cert\LocalAI_Server.cer
)

if not exist "%CER_FILE%" (
    echo [ERROR] 証明書ファイルが見つかりません:
    echo         LocalAI_Server.cer
    echo サーバー側の cert\LocalAI_Server.cer をこのフォルダに配置してください。
    echo.
    pause
    exit /b 1
)

echo 証明書をインストールしています: %CER_FILE% ...
certutil -addstore -f "ROOT" "%CER_FILE%" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ==============================================================================
    echo [SUCCESS] サーバー証明書が「信頼されたルート証明機関」に登録されました！
    echo ブラウザを再起動後、https:// から始まるURLへアクセスしてください。
    echo ==============================================================================
) else (
    echo.
    echo [ERROR] 証明書の登録に失敗しました。(コード: %ERRORLEVEL%)
)

echo.
pause
