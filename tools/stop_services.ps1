param(
    [string]$RootDir = "",
    [int]$VscodePort = 8000,
    [int]$HttpsPort = 8443,
    [int]$LlamaPort = 58080,
    [switch]$Quiet
)

$ErrorActionPreference = 'SilentlyContinue'

# Normalize RootDir
if (-not $RootDir) {
    $RootDir = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
}
$RootDir = (Resolve-Path $RootDir).Path.TrimEnd('\')

function Log-Msg([string]$msg) {
    if (-not $Quiet) {
        Write-Host $msg
    }
}

Log-Msg "   Root directory: $RootDir"

# 1. Terminate processes listening on configured ports (with full process tree)
$ports = @($VscodePort, $HttpsPort, $LlamaPort) | Where-Object { $_ -and $_ -gt 0 } | Select-Object -Unique

foreach ($port in $ports) {
    $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conns) {
        $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique | Where-Object { $_ -gt 4 }
        foreach ($pidToKill in $pids) {
            Log-Msg "   [Port $port] Terminating process tree (PID: $pidToKill)..."
            Start-Process -FilePath "taskkill.exe" -ArgumentList "/PID $pidToKill /T /F" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        }
    }
}

# 2. Terminate any residual/orphaned processes running from this portable package
# Specifically targets node.exe, Code.exe, code-tunnel.exe, llama-server.exe
$targetExeNames = @('node.exe', 'Code.exe', 'code-tunnel.exe', 'llama-server.exe')

$allProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
$residualProcs = $allProcs | Where-Object {
    if ($targetExeNames -notcontains $_.Name) { return $false }
    $exePath = $_.ExecutablePath
    $cmdLine = $_.CommandLine
    $isOurs = ($exePath -and $exePath.StartsWith($RootDir, [System.StringComparison]::OrdinalIgnoreCase)) -or
              ($cmdLine -and $cmdLine.IndexOf($RootDir, [System.StringComparison]::OrdinalIgnoreCase) -ge 0)
    return $isOurs
}

if ($residualProcs) {
    foreach ($proc in $residualProcs) {
        Log-Msg "   [Residual] Terminating $($proc.Name) (PID: $($proc.ProcessId))..."
        Start-Process -FilePath "taskkill.exe" -ArgumentList "/PID $($proc.ProcessId) /T /F" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    }
}

# 3. Wait until ports are released (up to 3 seconds)
$allReleased = $false
for ($i = 0; $i -lt 30; $i++) {
    $stillBound = $false
    foreach ($port in $ports) {
        $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($conns) {
            $stillBound = $true
            break
        }
    }
    if (-not $stillBound) {
        $allReleased = $true
        break
    }
    Start-Sleep -Milliseconds 100
}

if ($allReleased) {
    Log-Msg "   [SUCCESS] All LocalAI processes and network ports have been cleaned."
} else {
    Log-Msg "   [INFO] Ports are clearing up (TCP socket in closing state)."
}
