<#
.SYNOPSIS
    LocalAI Portable - Portable Python Environment Setup Script
.DESCRIPTION
    Downloads and configures an embeddable, fully portable Python runtime for Windows x64
    bundled with libraries for manipulating:
    - Excel (.xlsx, .xls) via openpyxl, pandas, xlrd, xlsxwriter
    - CSV and multi-language source code via pandas, chardet, charset-normalizer, pygments, rich
    - Oracle Database via oracledb (Pure Python Thin Mode, No Oracle Client required)
    - PostgreSQL Database via psycopg2-binary
    - Unified database interaction via SQLAlchemy
.PARAMETER DryRun
    Tests the logic without downloading or modifying files.
.PARAMETER Force
    Reinstalls Python even if already present.
#>

param(
    [switch]$DryRun,
    [switch]$Force
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = "Stop"

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$BinPythonDir = Join-Path $RootDir "bin\python"
$TempDir = Join-Path $RootDir "_temp_downloads"

$PythonVersion = "3.11.9"
$PythonZipUrl = "https://www.python.org/ftp/python/$PythonVersion/python-$PythonVersion-embed-amd64.zip"
$GetPipUrl = "https://bootstrap.pypa.io/get-pip.py"

# Target packages required for Excel, CSV, Source code, Oracle, PostgreSQL
$RequiredPackages = @(
    "openpyxl",
    "pandas",
    "xlrd",
    "xlsxwriter",
    "psycopg2-binary",
    "oracledb",
    "sqlalchemy",
    "chardet",
    "charset-normalizer",
    "rich",
    "pygments"
)

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "      LocalAI Portable - Portable Python Environment Setup" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Root Directory   : $RootDir"
Write-Host "Python Target Dir: $BinPythonDir"
if ($DryRun) {
    Write-Host "[MODE] DRY RUN (No files will be downloaded or modified)" -ForegroundColor Magenta
}
Write-Host ""

$pythonExe = Join-Path $BinPythonDir "python.exe"

if ((Test-Path $pythonExe) -and !$Force) {
    Write-Host "[INFO] Portable Python is already installed at $BinPythonDir" -ForegroundColor Green
    Write-Host "       Checking installed libraries..." -ForegroundColor DarkGray
    try {
        & "$pythonExe" -c "import pandas, openpyxl, oracledb, psycopg2, sqlalchemy, chardet; print('  [OK] Key libraries (pandas, openpyxl, oracledb, psycopg2, sqlalchemy, chardet) are ready.')"
        Write-Host "[SUCCESS] Portable Python environment is already configured." -ForegroundColor Green
        return
    }
    catch {
        Write-Host "  [WARNING] Some libraries might be missing. Proceeding with package installation..." -ForegroundColor Yellow
    }
}

if (!(Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir | Out-Null }
if (!(Test-Path $BinPythonDir)) { New-Item -ItemType Directory -Path $BinPythonDir | Out-Null }

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

# ------------------------------------------------------------------------------
# 1. Download & Extract Embeddable Python
# ------------------------------------------------------------------------------
$pythonZip = Join-Path $TempDir "python-$PythonVersion-embed-amd64.zip"

if (!(Test-Path $pythonExe) -or $Force) {
    Write-Host "`n--- [1/4] Downloading Python $PythonVersion Embeddable Package ---" -ForegroundColor Cyan
    Download-FileWithProgress -Url $PythonZipUrl -Destination $pythonZip -Description "Python $PythonVersion Embeddable x64"

    if (!$DryRun) {
        Write-Host "  [Extracting] $pythonZip -> $BinPythonDir" -ForegroundColor Yellow
        Expand-Archive -Path $pythonZip -DestinationPath $BinPythonDir -Force
        Remove-Item $pythonZip -Force -ErrorAction SilentlyContinue
        Write-Host "  [OK] Python embeddable extracted successfully." -ForegroundColor Green
    }
} else {
    Write-Host "`n--- [1/4] Python executable already present. Skipping extraction. ---" -ForegroundColor DarkGray
}

if ($DryRun) {
    Write-Host "`n[DRY RUN] Completed dry run for Portable Python setup." -ForegroundColor Magenta
    return
}

# ------------------------------------------------------------------------------
# 2. Configure ._pth file to enable site-packages and import site
# ------------------------------------------------------------------------------
Write-Host "`n--- [2/4] Configuring Python Path and site-packages ---" -ForegroundColor Cyan
$majorMinor = ($PythonVersion.Split('.')[0] + $PythonVersion.Split('.')[1])
$pthFile = Join-Path $BinPythonDir "python$majorMinor._pth"

if (Test-Path $pthFile) {
    Write-Host "  Updating $pthFile to enable site-packages and standard imports..." -ForegroundColor DarkGray
    $pthLines = @(
        "python$majorMinor.zip",
        ".",
        "Lib",
        "Lib\site-packages",
        "import site"
    )
    [System.IO.File]::WriteAllLines($pthFile, $pthLines, [System.Text.Encoding]::ASCII)
    Write-Host "  [OK] Configured $pthFile with 'import site' and 'Lib\site-packages'." -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Could not find $pthFile. Skipping _pth modification." -ForegroundColor DarkYellow
}

# ------------------------------------------------------------------------------
# 3. Download & Install pip via get-pip.py
# ------------------------------------------------------------------------------
Write-Host "`n--- [3/4] Installing / Verifying pip ---" -ForegroundColor Cyan
$pipExe = Join-Path $BinPythonDir "Scripts\pip.exe"
$getPipPy = Join-Path $TempDir "get-pip.py"

if (!(Test-Path $pipExe)) {
    Download-FileWithProgress -Url $GetPipUrl -Destination $getPipPy -Description "pip bootstrapper (get-pip.py)"
    Write-Host "  [Running] get-pip.py..." -ForegroundColor Yellow
    & "$pythonExe" "$getPipPy" --no-warn-script-location
    Remove-Item $getPipPy -Force -ErrorAction SilentlyContinue
    Write-Host "  [OK] pip installed successfully." -ForegroundColor Green
} else {
    Write-Host "  pip is already present at $pipExe" -ForegroundColor DarkGray
}

# ------------------------------------------------------------------------------
# 4. Install Target Libraries (Excel, CSV, Oracle, Postgres, SQLAlchemy)
# ------------------------------------------------------------------------------
Write-Host "`n--- [4/4] Installing Libraries for Excel, CSV, Oracle, PostgreSQL ---" -ForegroundColor Cyan
Write-Host "  Target packages: $($RequiredPackages -join ', ')" -ForegroundColor Yellow

$pipArgs = @("-m", "pip", "install", "--no-warn-script-location", "--upgrade") + $RequiredPackages
Write-Host "  Executing: python $($pipArgs -join ' ')..." -ForegroundColor DarkGray
& "$pythonExe" $pipArgs

# Clean up pip cache to save space in portable distribution
Write-Host "  Purging pip cache to reduce package footprint..." -ForegroundColor DarkGray
& "$pythonExe" -m pip cache purge 2>$null | Out-Null

# Cleanup temp dir
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------------------
# 5. Verification
# ------------------------------------------------------------------------------
Write-Host "`n--- Verifying Installed Libraries ---" -ForegroundColor Cyan
$verifyScript = @"
import sys
libs = ['openpyxl', 'pandas', 'xlrd', 'xlsxwriter', 'psycopg2', 'oracledb', 'sqlalchemy', 'chardet', 'rich', 'pygments']
success = []
failed = []
for lib in libs:
    try:
        __import__(lib)
        success.append(lib)
    except Exception as e:
        failed.append((lib, str(e)))

print('Successfully imported:', ', '.join(success))
if failed:
    print('Failed to import:', failed)
    sys.exit(1)
else:
    print('ALL PACKAGES VERIFIED SUCCESSFULLY!')
"@

$verifyFile = Join-Path $BinPythonDir "_verify_test.py"
[System.IO.File]::WriteAllText($verifyFile, $verifyScript, [System.Text.Encoding]::UTF8)

try {
    & "$pythonExe" "$verifyFile"
}
finally {
    Remove-Item $verifyFile -Force -ErrorAction SilentlyContinue
}

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " [SUCCESS] Portable Python environment is fully ready for LocalAI Portable!" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Green
