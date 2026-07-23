param(
    [Parameter(Mandatory = $true)]
    [string]$BackendUrl
)

$ErrorActionPreference = "Stop"

# ============================================================
# LOKASI PROJECT
# ============================================================

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendEnvPath = Join-Path $repoRoot "backend\.env"
$frontendPath = Join-Path $repoRoot "frontend"

# ============================================================
# VALIDASI BACKEND URL
# ============================================================

$BackendUrl = $BackendUrl.Trim().TrimEnd("/")

if ([string]::IsNullOrWhiteSpace($BackendUrl)) {
    throw "URL backend belum diisi."
}

if (-not $BackendUrl.StartsWith("https://")) {
    Write-Warning (
        "Backend masih menggunakan HTTP. " +
        "Untuk APK final sebaiknya gunakan HTTPS."
    )
}

$apiBaseUrl = "$BackendUrl/api"

# ============================================================
# MEMBACA TOKEN MAPBOX DARI BACKEND/.ENV
# ============================================================

if (-not (Test-Path $backendEnvPath)) {
    throw "File backend\.env tidak ditemukan: $backendEnvPath"
}

$tokenLine = Get-Content $backendEnvPath |
    Where-Object {
        $_ -match "^\s*MAPBOX_ACCESS_TOKEN\s*="
    } |
    Select-Object -First 1

if (-not $tokenLine) {
    throw "MAPBOX_ACCESS_TOKEN tidak ditemukan di backend\.env"
}

$mapboxToken = ($tokenLine -split "=", 2)[1].Trim()
$mapboxToken = $mapboxToken.Trim('"').Trim("'")

if ([string]::IsNullOrWhiteSpace($mapboxToken)) {
    throw "MAPBOX_ACCESS_TOKEN di backend\.env masih kosong."
}

if (-not $mapboxToken.StartsWith("pk.")) {
    throw (
        "Flutter membutuhkan public token Mapbox " +
        "yang diawali dengan pk."
    )
}

# ============================================================
# MEMERIKSA FLUTTER
# ============================================================

Write-Host ""
Write-Host "Memeriksa instalasi Flutter..." -ForegroundColor Cyan

& flutter doctor

if ($LASTEXITCODE -ne 0) {
    throw "Flutter doctor menemukan masalah."
}

# ============================================================
# MEMBERSIHKAN DAN MEMBANGUN APK
# ============================================================

Push-Location $frontendPath

try {
    Write-Host ""
    Write-Host "Mengambil dependency Flutter..." -ForegroundColor Cyan

    & flutter pub get

    if ($LASTEXITCODE -ne 0) {
        throw "flutter pub get gagal."
    }

    Write-Host ""
    Write-Host "Memeriksa source code..." -ForegroundColor Cyan

    & flutter analyze

    if ($LASTEXITCODE -ne 0) {
        throw "flutter analyze menemukan masalah."
    }

    Write-Host ""
    Write-Host "Membangun APK release..." -ForegroundColor Cyan
    Write-Host "API backend: $apiBaseUrl" -ForegroundColor DarkGray
    Write-Host ""

    $flutterArguments = @(
        "build"
        "apk"
        "--release"
        "--dart-define=API_BASE_URL=$apiBaseUrl"
        "--dart-define=MAPBOX_ACCESS_TOKEN=$mapboxToken"
    )

    & flutter @flutterArguments

    if ($LASTEXITCODE -ne 0) {
        throw "Build APK gagal."
    }

    $apkPath = Join-Path `
        $frontendPath `
        "build\app\outputs\flutter-apk\app-release.apk"

    if (-not (Test-Path $apkPath)) {
        throw "APK tidak ditemukan setelah proses build."
    }

    Write-Host ""
    Write-Host "============================================" `
        -ForegroundColor Green
    Write-Host "APK BERHASIL DIBUAT" -ForegroundColor Green
    Write-Host "============================================" `
        -ForegroundColor Green
    Write-Host $apkPath -ForegroundColor Yellow
    Write-Host ""
}
finally {
    Pop-Location
}