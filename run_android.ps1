param(
    [string]$DeviceId = ""
)

$ErrorActionPreference = "Stop"

# ============================================================
# LOKASI PROJECT
# ============================================================

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendEnvPath = Join-Path $repoRoot "backend\.env"
$frontendPath = Join-Path $repoRoot "frontend"

# ============================================================
# VALIDASI BACKEND ENV
# ============================================================

if (-not (Test-Path $backendEnvPath)) {
    throw "File backend\.env tidak ditemukan: $backendEnvPath"
}

# ============================================================
# MEMBACA MAPBOX ACCESS TOKEN
# ============================================================

$tokenLine = Get-Content $backendEnvPath |
    Where-Object {
        $_ -match "^\s*MAPBOX_ACCESS_TOKEN\s*="
    } |
    Select-Object -First 1

if (-not $tokenLine) {
    throw "MAPBOX_ACCESS_TOKEN tidak ditemukan di backend\.env"
}

$mapboxToken = ($tokenLine -split "=", 2)[1].Trim()

# Hapus tanda kutip jika token ditulis memakai kutip.
$mapboxToken = $mapboxToken.Trim('"').Trim("'")

if ([string]::IsNullOrWhiteSpace($mapboxToken)) {
    throw "MAPBOX_ACCESS_TOKEN di backend\.env masih kosong"
}

if (-not $mapboxToken.StartsWith("pk.")) {
    throw "Flutter Android membutuhkan public token Mapbox yang diawali pk."
}

# ============================================================
# MEMERIKSA PERANGKAT
# ============================================================

Write-Host ""
Write-Host "Perangkat Flutter yang tersedia:" -ForegroundColor Cyan
& flutter devices
Write-Host ""

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    $DeviceId = Read-Host "Masukkan Device ID HP Android"
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
    throw "Device ID belum diisi."
}

# ============================================================
# MENERUSKAN PORT BACKEND LAPTOP KE HP
# ============================================================

# ============================================================
# MENCARI ADB.EXE
# ============================================================

$adbCandidates = @()

if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME)) {
    $adbCandidates += Join-Path `
        $env:ANDROID_HOME `
        "platform-tools\adb.exe"
}

if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT)) {
    $adbCandidates += Join-Path `
        $env:ANDROID_SDK_ROOT `
        "platform-tools\adb.exe"
}

if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
    $adbCandidates += Join-Path `
        $env:LOCALAPPDATA `
        "Android\Sdk\platform-tools\adb.exe"
}

$adbPath = $adbCandidates |
    Where-Object {
        Test-Path $_
    } |
    Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($adbPath)) {
    throw (
        "adb.exe tidak ditemukan. " +
        "Pastikan Android SDK Platform-Tools sudah terpasang. " +
        "Periksa Android Studio > SDK Manager > SDK Tools."
    )
}

Write-Host ""
Write-Host "ADB ditemukan:" -ForegroundColor Green
Write-Host $adbPath -ForegroundColor DarkGray
Write-Host ""

# ============================================================
# MEMERIKSA KONEKSI PERANGKAT
# ============================================================

& $adbPath -s $DeviceId get-state

if ($LASTEXITCODE -ne 0) {
    throw (
        "Perangkat Android dengan ID '$DeviceId' tidak dapat diakses. " +
        "Pastikan USB debugging aktif dan izin debugging telah diterima."
    )
}

# ============================================================
# MENERUSKAN PORT BACKEND LAPTOP KE HP
# ============================================================

Write-Host "Menghubungkan port backend melalui ADB..." `
    -ForegroundColor Cyan

& $adbPath `
    -s $DeviceId `
    reverse `
    tcp:3000 `
    tcp:3000

if ($LASTEXITCODE -ne 0) {
    throw (
        "ADB reverse gagal. Pastikan HP tersambung melalui USB, " +
        "USB debugging aktif, dan perangkat sudah diotorisasi."
    )
}

Write-Host (
    "Port berhasil diteruskan: " +
    "HP localhost:3000 -> laptop localhost:3000"
) -ForegroundColor Green

# ============================================================
# MENJALANKAN FLUTTER ANDROID
# ============================================================

Write-Host ""
Write-Host "Token Mapbox berhasil dibaca dari backend\.env" `
    -ForegroundColor Green

Write-Host "Menjalankan RunNotPace pada Android..." `
    -ForegroundColor Cyan

Write-Host ""

Push-Location $frontendPath

try {
    $flutterArguments = @(
        "run"
        "-d"
        $DeviceId
        "--dart-define=API_BASE_URL=http://127.0.0.1:3000/api"
        "--dart-define=MAPBOX_ACCESS_TOKEN=$mapboxToken"
    )

    & flutter @flutterArguments
}
finally {
    Pop-Location
}