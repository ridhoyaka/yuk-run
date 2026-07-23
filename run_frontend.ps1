$ErrorActionPreference = "Stop"

# ============================================================
# MENENTUKAN LOKASI PROJECT
# ============================================================

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$backendEnvPath = Join-Path $repoRoot "backend\.env"
$frontendPath = Join-Path $repoRoot "frontend"

# ============================================================
# MEMERIKSA FILE ENV BACKEND
# ============================================================

if (-not (Test-Path $backendEnvPath)) {
    throw "File backend\.env tidak ditemukan di: $backendEnvPath"
}

# ============================================================
# MEMBACA MAPBOX_ACCESS_TOKEN
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

if ([string]::IsNullOrWhiteSpace($mapboxToken)) {
    throw "MAPBOX_ACCESS_TOKEN di backend\.env masih kosong"
}

if (-not $mapboxToken.StartsWith("pk.")) {
    throw "Frontend membutuhkan public token Mapbox yang diawali pk."
}

# ============================================================
# MENJALANKAN FLUTTER
# ============================================================

Write-Host ""
Write-Host "Token Mapbox berhasil dibaca dari backend\.env" -ForegroundColor Green
Write-Host "Menjalankan Flutter Web..." -ForegroundColor Cyan
Write-Host ""

Push-Location $frontendPath

try {
    $flutterArguments = @(
        "run"
        "-d"
        "chrome"
        "--dart-define=API_BASE_URL=http://localhost:3000/api"
        "--dart-define=MAPBOX_ACCESS_TOKEN=$mapboxToken"
    )

    & flutter @flutterArguments
}
finally {
    Pop-Location
}