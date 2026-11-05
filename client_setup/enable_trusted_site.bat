@echo off
setlocal enabledelayedexpansion
title LocalAI - Client Browser Trusted Site Setup

echo ==============================================================================
echo   LocalAI Portable - クライアントPC ブラウザ信頼済みサイト設定ツール
echo ==============================================================================
echo.
echo 本ツールは、Google Chrome および Microsoft Edge に対して、
echo 社内サーバーの LocalAI Web UI を「安全なサイト (Secure Context)」として登録します。
echo これにより、chrome://flags の手動設定を行うことなく、
echo Continue チャット画面（Webview / Service Worker）が正常に動作するようになります。
echo.
echo ※ 管理者権限は不要です（現在のユーザー環境に安全に登録されます）。
echo.

rem デフォルトのサーバーURL（必要に応じてサーバー名やIPに変更してください）
set DEFAULT_URL=http://%COMPUTERNAME%:8000
if exist "%~dp0..\config.env.bat" (
    for /f "tokens=2 delims==" %%a in ('findstr /i "^set VSCODE_PORT=" "%~dp0..\config.env.bat"') do (
        set DEFAULT_URL=http://%COMPUTERNAME%:%%a
    )
)

echo ------------------------------------------------------------------------------
echo 登録するサーバーのURLを入力してください（Enterでデフォルト値を使用）
echo [初期値]: %DEFAULT_URL%
echo ------------------------------------------------------------------------------
set /p TARGET_URL="URL: "
if "%TARGET_URL%"=="" set TARGET_URL=%DEFAULT_URL%

echo.
echo 登録中: %TARGET_URL% ...

rem 1. Google Chrome への登録
reg add "HKCU\Software\Policies\Google\Chrome\InsecureOriginsTreatAsSecure" /v 1 /t REG_SZ /d "%TARGET_URL%" /f >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Google Chrome への登録が完了しました。
) else (
    echo [SKIP] Google Chrome の登録をスキップしました。
)

rem 2. Microsoft Edge への登録
reg add "HKCU\Software\Policies\Microsoft\Edge\InsecureOriginsTreatAsSecure" /v 1 /t REG_SZ /d "%TARGET_URL%" /f >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Microsoft Edge への登録が完了しました。
) else (
    echo [SKIP] Microsoft Edge の登録をスキップしました。
)

echo.
echo ==============================================================================
echo [設定完了] ブラウザ（Chrome / Edge）を再起動してからアクセスしてください。
echo アクセス先: %TARGET_URL%
echo ==============================================================================
echo.
pause
