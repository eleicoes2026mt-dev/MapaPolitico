# build_apk.ps1 — Gera o APK de release com a API Key do ArcGIS.
#
# Uso:
#   .\build_apk.ps1               (lê a chave de arcgis_key.txt)
#   .\build_apk.ps1 --install     (instala no dispositivo conectado após buildar)
#
# Na primeira execução, cria arcgis_key.txt com a chave que você informar.
# Como obter a chave:
#   1. Acesse https://developers.arcgis.com
#   2. Faça login com a mesma conta (eleicoes2026)
#   3. Menu → API Keys → New API key → marque Basemaps + Location services → Create
#   4. Copie a chave (começa com AAPK...)

param (
    [switch]$Install
)

$ErrorActionPreference = "Stop"
$keyFile = "$PSScriptRoot\arcgis_key.txt"

# ─── Lê ou solicita a chave ───────────────────────────────────────────────────
if (Test-Path $keyFile) {
    $arcgisKey = (Get-Content $keyFile -Raw).Trim()
    Write-Host "✔ Usando chave ArcGIS de arcgis_key.txt" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "Chave ArcGIS não encontrada. Obtenha em:" -ForegroundColor Yellow
    Write-Host "  https://developers.arcgis.com → API Keys → New API key" -ForegroundColor Cyan
    Write-Host ""
    $arcgisKey = Read-Host "Cole a chave ArcGIS (AAPK...)"
    if ($arcgisKey.Length -lt 10) {
        Write-Error "Chave inválida. Tente novamente."
        exit 1
    }
    Set-Content -Path $keyFile -Value $arcgisKey -Encoding UTF8
    Write-Host "✔ Chave salva em arcgis_key.txt (não versionada pelo git)" -ForegroundColor Green
}

# ─── Build ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "Buildando APK (--split-per-abi)..." -ForegroundColor Cyan

$vapidPublicKey = "BBDwFPKAU0cMMay9-WE1DadHmv_lFmGts80CaorhOl2zKW1HTSw4sQLpboixKQkerXexwYwJxSF4PcOK35Qa2DY"

$defineArgs = @(
    "--dart-define=ARCGIS_API_KEY=$arcgisKey",
    "--dart-define=VAPID_PUBLIC_KEY=$vapidPublicKey"
) -join " "

flutter build apk --split-per-abi $defineArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build falhou (código $LASTEXITCODE)."
    exit $LASTEXITCODE
}

# ─── Localiza o APK arm64 (o mais comum em celulares modernos) ────────────────
$apkPath = "$PSScriptRoot\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
$apkFat  = "$PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"

$found = if (Test-Path $apkPath) { $apkPath } elseif (Test-Path $apkFat) { $apkFat } else { $null }

if ($found) {
    Write-Host ""
    Write-Host "✔ APK gerado em:" -ForegroundColor Green
    Write-Host "  $found" -ForegroundColor White
} else {
    Write-Host "APK não encontrado no caminho esperado. Verifique a pasta build\app\outputs\flutter-apk\" -ForegroundColor Yellow
}

# ─── Instala no dispositivo (opcional) ────────────────────────────────────────
if ($Install -and $found) {
    Write-Host ""
    Write-Host "Instalando no dispositivo conectado..." -ForegroundColor Cyan
    adb install -r $found
}

Write-Host ""
Write-Host "Pronto!" -ForegroundColor Green
