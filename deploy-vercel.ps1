# Deploy CampanhaMT (Flutter Web) para Vercel
# Uso: .\deploy-vercel.ps1   ou   .\deploy-vercel.ps1 -Preview  (sem --prod)

param([switch]$Preview)

Write-Host "Building Flutter web..." -ForegroundColor Cyan
flutter build web
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Copy-Item "vercel-web.json" -Destination "build\web\vercel.json"
Write-Host "Deploying to Vercel..." -ForegroundColor Cyan
Set-Location build\web
if ($Preview) {
    vercel
} else {
    vercel --prod --yes
}
Set-Location ..\..
