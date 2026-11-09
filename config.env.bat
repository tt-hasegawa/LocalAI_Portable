@echo off
rem ==============================================================================
rem LocalAI Portable Environment Configuration
rem ==============================================================================

rem --- Network & Ports ---
rem Set to 0.0.0.0 to allow access from other PCs on the network
set VSCODE_HOST=0.0.0.0
set VSCODE_PORT=8000

rem --- HTTPS / SSL Reverse Proxy ---
rem Set to 1 to enable built-in HTTPS reverse proxy (Port 8443)
rem Set to 0 to run plain HTTP only (Port 8000)
set ENABLE_HTTPS=1
set HTTPS_PORT=8443
set SSL_PASSPHRASE=localai

rem llama-server local endpoint (Changed from 8080 to avoid conflicts)
set LLAMA_HOST=127.0.0.1
set LLAMA_PORT=58080

rem --- llama-server CPU Inference Parameters ---
rem Number of CPU threads (Set to 0 to auto-detect physical CPU cores)
set CPU_THREADS=0

rem Context size in tokens (Default: 16384 for code inspection, 8192 or 4096 if memory permits)
set CTX_SIZE=16384

rem Model file name inside the models/ directory:
rem   [Code-Specialized Models]
rem   - Qwen2.5-Coder 3B (RAM 2.5-3.5GB) : Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf (Default)
rem   - Qwen2.5-Coder 1.5B (RAM 1.5-2.0GB): Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf
rem   [Ultra-Lightweight / General & Coding (<2GB RAM)]
rem   - Gemma-2-2B-IT (RAM 1.8-2.3GB)    : gemma-2-2b-it-Q4_K_M.gguf
rem   - Llama-3.2-1B-IT (RAM 1.2-1.5GB)  : Llama-3.2-1B-Instruct-Q4_K_M.gguf
set MODEL_NAME=Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf
rem set MODEL_NAME=gemma-2-2b-it-Q4_K_M.gguf
rem set MODEL_NAME=Llama-3.2-1B-Instruct-Q4_K_M.gguf
rem set MODEL_NAME=Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf

rem Batch size for CPU inference
set BATCH_SIZE=512

rem --- Default Workspace Folder ---
rem Optional: Set a directory path to auto-open on startup
rem Example: set DEFAULT_FOLDER=C:\source
set DEFAULT_FOLDER=

rem --- Relative Paths ---
set ROOT_DIR=%~dp0
set BIN_LLAMA=%ROOT_DIR%bin\llama\llama-server.exe
set BIN_VSCODE=%ROOT_DIR%bin\vscode\bin\code.cmd
set BIN_PYTHON=%ROOT_DIR%bin\python\python.exe
set MODELS_DIR=%ROOT_DIR%models
set DATA_DIR=%ROOT_DIR%data
set LOGS_DIR=%ROOT_DIR%logs
set EXT_INSTALLER_DIR=%ROOT_DIR%extensions_installer
