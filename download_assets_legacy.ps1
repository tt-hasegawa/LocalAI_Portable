<#
.SYNOPSIS
    LocalAI Portable - Legacy Assets Downloader and Setup Script (for Windows Server 2016)
.DESCRIPTION
    Downloads and extracts all required assets for offline portable usage on legacy Windows
    environments (such as Windows Server 2016 or Windows 10 prior to build 1809), which lack
    native ConPTY support and require VS Code with WinPTY support (v1.108 or earlier).

    - VS Code Portable (Legacy Windows x64 Zip, default: v1.108.2 with WinPTY)
    - llama.cpp (AVX2 CPU release for Windows)
    - Continue Extension (.vsix)
    - Japanese Language Pack (.vsix)
    - LLM GGUF Models
    - Portable Python 3.11 with Excel, CSV, Oracle, Postgres libraries
.PARAMETER VSCodeVersion
    Specifies the legacy VS Code version to download. Defaults to '1.108.2' (the last stable release before WinPTY removal).
.PARAMETER ForceVSCode
    Forces re-download and replacement of bin\vscode even if a VS Code installation is already present.
.PARAMETER DryRun
    Tests the script logic and checks URLs without downloading large files.
.PARAMETER SkipPython
    Skips downloading and configuring the portable Python environment.
.PARAMETER Models
    Specifies which models to download: 'All' (default), 'Qwen3B', 'Qwen15B', 'Llama1B', 'Gemma2B'.
#>

param(
    [string]$VSCodeVersion = "1.108.2",
    [switch]$ForceVSCode,
    [switch]$DryRun,
    [switch]$SkipPython,
    [ValidateSet("All", "Qwen3B", "Qwen15B", "Llama1B", "Gemma2B")]
    [string]$Models = "All"
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
Write-Host "  LocalAI Portable - Online Asset Downloader (Legacy WinPTY / Server 2016)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Root Directory  : $RootDir"
Write-Host "Target VS Code  : v$VSCodeVersion (with WinPTY support for Windows Server 2016)" -ForegroundColor Green
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
# 1. VS Code Windows x64 Portable (.zip) - Legacy Version (WinPTY Enabled)
# ------------------------------------------------------------------------------
$vscodeZip = Join-Path $TempDir "vscode-win32-x64-$VSCodeVersion.zip"
$vscodeCmd = Join-Path $BinVSCodeDir "bin\code.cmd"

$shouldDownloadVSCode = $true
if (Test-Path $vscodeCmd) {
    $installedVersion = ""
    try {
        $verOutput = & $vscodeCmd -v 2>$null
        if ($verOutput) {
            $installedVersion = ($verOutput -split '\r?\n')[0].Trim()
        }
    } catch {}

    if ($installedVersion -eq $VSCodeVersion -and !$ForceVSCode) {
        Write-Host "`n[1/5] VS Code v$installedVersion is already installed in bin\vscode. Skipping." -ForegroundColor DarkGray
        $shouldDownloadVSCode = $false
    } else {
        if ($installedVersion) {
            Write-Host "`n[1/5] Detected currently installed VS Code v$installedVersion (Target: v$VSCodeVersion)." -ForegroundColor Yellow
        } else {
            Write-Host "`n[1/5] VS Code is present but version could not be determined." -ForegroundColor Yellow
        }
        Write-Host "      Will replace bin\vscode with legacy version v$VSCodeVersion..." -ForegroundColor Yellow
    }
}

if ($shouldDownloadVSCode) {
    Write-Host "`n--- [1/5] Downloading Legacy VS Code Portable (v$VSCodeVersion) ---" -ForegroundColor Cyan
    $vscodeUrl = "https://update.code.visualstudio.com/$VSCodeVersion/win32-x64-archive/stable"
    Download-FileWithProgress -Url $vscodeUrl -Destination $vscodeZip -Description "VS Code v$VSCodeVersion (Windows x64 Zip)"
    
    if (!$DryRun) {
        # Clean existing bin\vscode if replacing
        if (Test-Path $vscodeCmd) {
            Write-Host "  [Cleaning] Removing existing bin\vscode contents before extracting..." -ForegroundColor DarkGray
            Get-ChildItem -Path $BinVSCodeDir -Recurse | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
        }

        Write-Host "  [Extracting] $vscodeZip -> $BinVSCodeDir" -ForegroundColor Yellow
        Expand-Archive -Path $vscodeZip -DestinationPath $BinVSCodeDir -Force
        Remove-Item $vscodeZip -Force -ErrorAction SilentlyContinue

        # Copy VC++ runtime DLLs to bin\vscode to ensure execution on Windows Server 2016 without VC++ Redistributable
        Write-Host "  [Bundling] Copying Visual C++ runtime DLLs to bin\vscode..." -ForegroundColor DarkGray
        $vcDlls = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "msvcp140_atomic_wait.dll", "vcruntime140.dll", "vcruntime140_1.dll")
        foreach ($d in $vcDlls) {
            $sysDll = Join-Path "C:\Windows\System32" $d
            if (Test-Path $sysDll) {
                Copy-Item $sysDll $BinVSCodeDir -Force -ErrorAction SilentlyContinue
            }
        }

        # Also ensure settings.json in portable user-data is configured to use native / winpty correctly
        $portableSettings = Join-Path $RootDir "data\user-data\User\settings.json"
        if (Test-Path $portableSettings) {
            try {
                $json = Get-Content $portableSettings -Raw | ConvertFrom-Json
                # On Windows Server 2016 with v1.108, windowsUseConptyDll is not needed or should be false so WinPTY is used as fallback
                $json | Add-Member -Name "terminal.integrated.windowsUseConptyDll" -Value $false -MemberType NoteProperty -Force
                $json | ConvertTo-Json -Depth 10 | Set-Content $portableSettings -Encoding UTF8
                Write-Host "  [Config] Set terminal.integrated.windowsUseConptyDll to false in user-data settings." -ForegroundColor DarkGray
            } catch {}
        }

        Write-Host "  [OK] Legacy VS Code v$VSCodeVersion extracted and configured successfully." -ForegroundColor Green
    }
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
# 5. LLM Models in GGUF Format
# ------------------------------------------------------------------------------
$modelTargets = @(
    @{
        Key = "Qwen3B"
        FileName = "Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf"
        Url = "https://huggingface.co/Qwen/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/qwen2.5-coder-3b-instruct-q4_k_m.gguf"
        Description = "Qwen2.5-Coder-3B-Instruct-Q4_K_M (Code Standard, ~1.96 GB)"
    },
    @{
        Key = "Qwen15B"
        FileName = "Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf"
        Url = "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf"
        Description = "Qwen2.5-Coder-1.5B-Instruct-Q4_K_M (Code Lightweight, ~1.04 GB)"
    },
    @{
        Key = "Llama1B"
        FileName = "Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        Url = "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf"
        Description = "Llama-3.2-1B-Instruct-Q4_K_M (Ultra Lightweight <2GB RAM, ~0.81 GB)"
    },
    @{
        Key = "Gemma2B"
        FileName = "gemma-2-2b-it-Q4_K_M.gguf"
        Url = "https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf"
        Description = "Gemma-2-2B-IT-Q4_K_M (High Performance <2GB RAM, ~1.71 GB)"
    }
)

Write-Host "`n--- [5/6] Checking / Downloading LLM GGUF Models ---" -ForegroundColor Cyan
foreach ($m in $modelTargets) {
    if ($Models -ne "All" -and $Models -ne $m.Key) {
        continue
    }

    $destPath = Join-Path $ModelsDir $m.FileName
    if (!(Test-Path $destPath)) {
        Write-Host "`n  [Model Download] $($m.Description)..." -ForegroundColor Yellow
        Download-FileWithProgress -Url $m.Url -Destination $destPath -Description $m.FileName
    } else {
        Write-Host "  [Ready] Model file is already present: $($m.FileName)" -ForegroundColor DarkGray
    }
}

# ------------------------------------------------------------------------------
# 6. Portable Python Environment (Excel, CSV, Oracle, PostgreSQL, Source Code)
# ------------------------------------------------------------------------------
if (!$SkipPython) {
    Write-Host "`n--- [6/6] Setting up Portable Python Environment ---" -ForegroundColor Cyan
    $setupPythonScript = Join-Path $RootDir "tools\setup_python.ps1"
    if (Test-Path $setupPythonScript) {
        $pythonArgs = @("-ExecutionPolicy", "Bypass", "-File", $setupPythonScript)
        if ($DryRun) { $pythonArgs += "-DryRun" }
        & powershell.exe $pythonArgs
    } else {
        Write-Host "  [WARNING] $setupPythonScript not found. Skipping." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "`n[6/6] Skipped Portable Python setup (-SkipPython specified)." -ForegroundColor DarkGray
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
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$installBat`" --no-pause" -Wait -NoNewWindow
    }
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " [SUCCESS] Legacy assets (VS Code v$VSCodeVersion) processed successfully!" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "You can now compress this 'LocalAI_Portable' directory into a Zip or 7z archive,"
Write-Host "transfer it to your Windows Server 2016 development server, and run 'start.bat'."
Write-Host "==============================================================================" -ForegroundColor Green
