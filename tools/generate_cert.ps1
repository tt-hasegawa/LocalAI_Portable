# ==============================================================================
# LocalAI Portable - Automated Self-Signed Certificate Generator
# Uses native Windows PowerShell (Zero OpenSSL / 3rd-party dependencies)
# ==============================================================================

param(
    [string]$CertDir = (Join-Path (Split-Path -Parent $PSScriptRoot) "cert"),
    [string]$Passphrase = "localai"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $CertDir)) {
    New-Item -ItemType Directory -Path $CertDir -Force | Out-Null
}

$pfxPath = Join-Path $CertDir "server.pfx"
$cerPath = Join-Path $CertDir "LocalAI_Server.cer"

if (Test-Path $pfxPath) {
    Write-Host "[INFO] SSL certificate server.pfx already exists in $CertDir. Skipping generation." -ForegroundColor Yellow
    exit 0
}

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "      Generating Self-Signed SSL Certificate for LocalAI Server" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# Gather DNS names and IP addresses for Subject Alternative Name (SAN)
$dnsNames = [System.Collections.Generic.List[string]]::new()
$dnsNames.Add($env:COMPUTERNAME)
$dnsNames.Add("localhost")
$dnsNames.Add("127.0.0.1")

try {
    $ipAddresses = [System.Net.Dns]::GetHostAddresses($env:COMPUTERNAME) | 
        Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } | 
        ForEach-Object { $_.IPAddressToString }
    foreach ($ip in $ipAddresses) {
        if (!$dnsNames.Contains($ip)) {
            $dnsNames.Add($ip)
        }
    }
} catch {}

Write-Host "Subject Alternative Names (SAN):" -ForegroundColor DarkGray
foreach ($d in $dnsNames) {
    Write-Host "  - $d" -ForegroundColor DarkGray
}

Write-Host "`nCreating self-signed certificate in Windows Certificate Store..." -ForegroundColor Yellow
$cert = New-SelfSignedCertificate `
    -DnsName $dnsNames `
    -CertStoreLocation "cert:\CurrentUser\My" `
    -NotAfter (Get-Date).AddYears(5) `
    -FriendlyName "LocalAI Portable HTTPS Certificate" `
    -KeyExportPolicy Exportable `
    -KeyLength 2048 `
    -HashAlgorithm SHA256

$secPass = ConvertTo-SecureString -String $Passphrase -Force -AsPlainText

Write-Host "Exporting PFX certificate to: $pfxPath" -ForegroundColor DarkGray
Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $secPass | Out-Null

Write-Host "Exporting public certificate to: $cerPath" -ForegroundColor DarkGray
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

# Clean up private key from CurrentUser\My to keep store tidy (pfx file retains the key)
Remove-Item ("cert:\CurrentUser\My\" + $cert.Thumbprint) -Force -ErrorAction SilentlyContinue

Write-Host "`n[SUCCESS] SSL certificates generated successfully!" -ForegroundColor Green
Write-Host "  - Server PFX: $pfxPath" -ForegroundColor Green
Write-Host "  - Public CER: $cerPath (Distribute this to client PCs if needed)" -ForegroundColor Green
Write-Host "==============================================================================`n"
