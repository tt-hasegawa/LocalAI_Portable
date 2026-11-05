<#
.SYNOPSIS
    LocalAI Portable - Assets Downloader and Setup Script
.DESCRIPTION
    Downloads and extracts all required assets for offline portable usage:
    - VS Code Portable (Windows x64 Zip)
    - llama.cpp (AVX2 CPU release for Windows)
    - Continue Extension (.vsix)
    - Japanese Language Pack (.vsix)
    - Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf
.PARAMETER DryRun
    Tests the script logic and checks URLs without downloading large files.
#>

param(
    [switch]$DryRun
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BinLlamaDir = Join-Path $RootDir "bin\llama"
$BinVSCodeDir = Join-Path $RootDir "bin\vscode"
$ModelsDir = Join-Path $RootDir "models"
$ExtInstallerDir = Join-Path $RootDir "extensions_installer"
$TempDir = Join-Path $RootDir "_temp_downloads"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "      LocalAI Portable - Online Asset Downloader" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Root Directory: $RootDir"
if ($DryRun) {
    Write-Host "[MODE] DRY RUN (No files will be downloaded)" -ForegroundColor Magenta
}
Write-Host ""

# Ensure directories exist
if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }
if (!(Test-Path $BinLlamaDir)) { New-Item -ItemType Directory -Path $BinLlamaDir | Out-Null }
if (!(Test-Path $BinVSCodeDir)) { New-Item -ItemType Directory -Path $BinVSCodeDir | Out-Null }
if (!(Test-Path $ModelsDir)) { New-Item -ItemType Directory -Path $ModelsDir | Out-Null }
if (!(Test-Path $ExtInstallerDir)) { New-Item -ItemType Directory -Path $ExtInstallerDir | Out-Null }

function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Description
    )
    Write-Host "[Downloading] $Description" -ForegroundColor Yellow
    Write-Host "  URL: $Url" -ForegroundColor DarkGray
    Write-Host "  Destination: $Destination" -ForegroundColor DarkGray
    
    if ($DryRun) {
        Write-Host "  [DRY RUN] Skipping actual download." -ForegroundColor Magenta
        return
    }

    $client = New-Object System.Net.WebClient
    try {
        $client.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $client.DownloadFile($Url, $Destination)
        Write-Host "  [OK] Download completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "  [ERROR] Failed to download: $_" -ForegroundColor Red
        throw $_
    }
    finally {
        $client.Dispose()
    }
}

function Ensure-VsixDecompressed {
    param([string]$FilePath)
    if (!(Test-Path $FilePath)) { return }
    if ($DryRun) { return }

    try {
        $fs = [System.IO.File]::OpenRead($FilePath)
        $b1 = $fs.ReadByte()
        $b2 = $fs.ReadByte()
        $fs.Dispose()

        # Check for GZIP magic header: 0x1F 0x8B
        if ($b1 -eq 0x1F -and $b2 -eq 0x8B) {
            Write-Host "  [Fixing] Marketplace gzip wrapper detected. Decompressing: $(Split-Path $FilePath -Leaf)..." -ForegroundColor Yellow
            $tempGz = $FilePath + ".tmp.gz"
            Move-Item -Path $FilePath -Destination $tempGz -Force
            
            $inStream = [System.IO.File]::OpenRead($tempGz)
            $gzStream = New-Object System.IO.Compression.GZipStream($inStream, [System.IO.Compression.CompressionMode]::Decompress)
            $outStream = [System.IO.File]::Create($FilePath)
            $gzStream.CopyTo($outStream)
            $gzStream.Dispose()
            $outStream.Dispose()
            $inStream.Dispose()
            Remove-Item -Path $tempGz -Force -ErrorAction SilentlyContinue
            Write-Host "  [OK] Successfully converted to standard VSIX (ZIP)." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  [WARNING] Failed to inspect/decompress VSIX: $_" -ForegroundColor DarkYellow
    }
}

# ------------------------------------------------------------------------------
# 1. VS Code Windows x64 Portable (.zip)
# ------------------------------------------------------------------------------
$vscodeZip = Join-Path $TempDir "vscode-win32-x64.zip"
$vscodeCmd = Join-Path $BinVSCodeDir "bin\code.cmd"
if (!(Test-Path $vscodeCmd)) {
    Write-Host "`n--- [1/5] Downloading VS Code Portable ---" -ForegroundColor Cyan
    $vscodeUrl = "https://update.code.visualstudio.com/latest/win32-x64-archive/stable"
    Download-FileWithProgress -Url $vscodeUrl -Destination $vscodeZip -Description "VS Code (Windows x64 Zip)"
    
    if (!$DryRun) {
        Write-Host "  [Extracting] $vscodeZip -> $BinVSCodeDir" -ForegroundColor Yellow
        Expand-Archive -Path $vscodeZip -DestinationPath $BinVSCodeDir -Force
        Remove-Item $vscodeZip -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] VS Code extracted successfully." -ForegroundColor Green
    }
} else {
    Write-Host "`n[1/5] VS Code is already present. Skipping." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 2. llama.cpp Windows AVX2 (CPU build)
# ------------------------------------------------------------------------------
$llamaZip = Join-Path $TempDir "llama-win-avx2-x64.zip"
$llamaExe = Join-Path $BinLlamaDir "llama-server.exe"
if (!(Test-Path $llamaExe)) {
    Write-Host "`n--- [2/5] Downloading llama.cpp (AVX2 CPU Release) ---" -ForegroundColor Cyan
    try {
        Write-Host "  Querying latest llama.cpp release from GitHub API..." -ForegroundColor DarkGray
        $releaseApi = "https://api.github.com/repos/ggml-org/llama.cpp/releases?per_page=1"
        $headers = @{ "User-Agent" = "PowerShell-LocalAI" }
        $releaseInfo = Invoke-RestMethod -Uri $releaseApi -Headers $headers -TimeoutSec 15
        
        $latestRel = if ($releaseInfo -is [array]) { $releaseInfo[0] } else { $releaseInfo }
        $asset = $latestRel.assets | Where-Object { $_.name -like "*bin-win-cpu-x64.zip" -or $_.name -like "*bin-win-avx2-x64.zip" } | Select-Object -First 1
        if ($asset) {
            $llamaUrl = $asset.browser_download_url
            Write-Host "  Found release asset: $($asset.name)" -ForegroundColor DarkGray
        } else {
            throw "Could not find CPU release asset in latest release."
        }
    }
    catch {
        Write-Host "  GitHub API query failed, falling back to direct release download: $_" -ForegroundColor DarkYellow
        $llamaUrl = "https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-bin-win-cpu-x64.zip"
    }

    Download-FileWithProgress -Url $llamaUrl -Destination $llamaZip -Description "llama.cpp AVX2 Windows x64"
    if (!$DryRun) {
        Write-Host "  [Extracting] $llamaZip -> $BinLlamaDir" -ForegroundColor Yellow
        Expand-Archive -Path $llamaZip -DestinationPath $BinLlamaDir -Force
        Remove-Item $llamaZip -Force -ErrorAction SilentlyContinue

        # Copy VC++ runtime DLLs from System32 to ensure standalone execution on Windows Server
        Write-Host "  [Bundling] Copying Visual C++ runtime DLLs..." -ForegroundColor DarkGray
        $vcDlls = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "msvcp140_atomic_wait.dll", "vcruntime140.dll", "vcruntime140_1.dll")
        foreach ($d in $vcDlls) {
            $sysDll = Join-Path "C:\Windows\System32" $d
            if (Test-Path $sysDll) {
                Copy-Item $sysDll $BinLlamaDir -Force -ErrorAction SilentlyContinue
            }
        }

        Write-Host "  [OK] llama.cpp extracted and runtime bundled successfully." -ForegroundColor Green
    }
} else {
    Write-Host "`n[2/5] llama-server.exe is already present. Skipping." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 3. Continue Extension (win32-x64 VSIX)
# ------------------------------------------------------------------------------
$continueVsix = Join-Path $ExtInstallerDir "continue.vsix"
if (!(Test-Path $continueVsix)) {
    Write-Host "`n--- [3/5] Downloading Continue Extension (win32-x64 VSIX) ---" -ForegroundColor Cyan
    $continueUrl = "https://open-vsx.org/api/Continue/continue/win32-x64/2.1.0/file/Continue.continue-2.1.0@win32-x64.vsix"
    try {
        Download-FileWithProgress -Url $continueUrl -Destination $continueVsix -Description "Continue Extension (win32-x64 VSIX)"
    } catch {
        Write-Host "  OpenVSX download failed, falling back to VS Code Marketplace..." -ForegroundColor DarkYellow
        $continueUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/Continue/vsextensions/continue/latest/vspackage?targetPlatform=win32-x64"
        Download-FileWithProgress -Url $continueUrl -Destination $continueVsix -Description "Continue Extension (Marketplace win32-x64)"
    }
    Ensure-VsixDecompressed -FilePath $continueVsix
} else {
    Ensure-VsixDecompressed -FilePath $continueVsix
    Write-Host "`n[3/5] Continue VSIX is already present. Skipping." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 4. Japanese Language Pack (VSIX, Optional)
# ------------------------------------------------------------------------------
$jaVsix = Join-Path $ExtInstallerDir "vscode-language-pack-ja.vsix"
if (!(Test-Path $jaVsix)) {
    Write-Host "`n--- [4/5] Downloading Japanese Language Pack (VSIX) ---" -ForegroundColor Cyan
    $jaUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/MS-CEINTL/vsextensions/vscode-language-pack-ja/latest/vspackage"
    try {
        Download-FileWithProgress -Url $jaUrl -Destination $jaVsix -Description "Japanese Language Pack"
        Ensure-VsixDecompressed -FilePath $jaVsix
    } catch {
        Write-Host "  [INFO] Skipped Japanese language pack. English UI will be used." -ForegroundColor DarkGray
    }
} else {
    Ensure-VsixDecompressed -FilePath $jaVsix
    Write-Host "`n[4/5] Japanese language pack VSIX is already present. Skipping." -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 5. Qwen2.5-Coder Models (3B Standard & 1.5B Lightweight for <= 8GB RAM)
# ------------------------------------------------------------------------------
$modelPath3B = Join-Path $ModelsDir "Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf"
if (!(Test-Path $modelPath3B)) {
    Write-Host "`n--- [5/5] Downloading Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf ---" -ForegroundColor Cyan
    Write-Host "  File size is approximately 1.96 GB. Downloading..." -ForegroundColor Yellow
    $modelUrl3B = "https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
    Download-FileWithProgress -Url $modelUrl3B -Destination $modelPath3B -Description "Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf"
} else {
    Write-Host "`n[5/5] 3B Model file is already present: $modelPath3B" -ForegroundColor DarkGray
}

$modelPath15B = Join-Path $ModelsDir "Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf"
if (!(Test-Path $modelPath15B)) {
    Write-Host "`n--- Downloading Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf (Lightweight) ---" -ForegroundColor Cyan
    Write-Host "  File size is approximately 1.04 GB. Downloading..." -ForegroundColor Yellow
    $modelUrl15B = "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
    Download-FileWithProgress -Url $modelUrl15B -Destination $modelPath15B -Description "Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf"
} else {
    Write-Host "1.5B Model file is already present: $modelPath15B" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# Cleanup temporary downloads
# ------------------------------------------------------------------------------
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------------
# Install extensions into portable environment
# ------------------------------------------------------------------------------
if (!$DryRun) {
    Write-Host "`n--- Installing Extensions into Portable Environment ---" -ForegroundColor Cyan
    # Ensure all vsix files in extensions_installer are decompressed standard zip
    Get-ChildItem -Path $ExtInstallerDir -Filter "*.vsix" | ForEach-Object {
        Ensure-VsixDecompressed -FilePath $_.FullName
    }

    $installBat = Join-Path $RootDir "install_extensions.bat"
    if (Test-Path $installBat) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$installBat`"" -Wait -NoNewWindow
    }
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " [SUCCESS] All assets have been processed successfully!" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "You can now compress this 'LocalAI_Portable' directory into a Zip or 7z archive,"
Write-Host "transfer it to your air-gapped development server, and run 'start.bat'."
Write-Host "==============================================================================" -ForegroundColor Green
