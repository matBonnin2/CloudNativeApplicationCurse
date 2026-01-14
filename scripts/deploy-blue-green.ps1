# =============================================================================
# Script de deploiement Blue/Green
# Usage: .\scripts\deploy-blue-green.ps1 -ImageTag "sha" -ImageBackend "url" -ImageFrontend "url"
# =============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ImageTag,

    [Parameter(Mandatory=$true)]
    [string]$ImageBackend,

    [Parameter(Mandatory=$true)]
    [string]$ImageFrontend,

    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  BLUE/GREEN DEPLOYMENT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# =============================================================================
# Etape 1 : Determiner la couleur active et cible
# =============================================================================
$activeColorFile = Join-Path $ProjectRoot ".active_color"

if (Test-Path $activeColorFile) {
    $currentColor = (Get-Content $activeColorFile -Raw).Trim()
} else {
    $currentColor = "blue"
    "blue" | Out-File -FilePath $activeColorFile -NoNewline -Encoding utf8
}

$targetColor = if ($currentColor -eq "blue") { "green" } else { "blue" }

Write-Host ""
Write-Host "Couleur active actuelle : $currentColor" -ForegroundColor Yellow
Write-Host "Couleur cible           : $targetColor" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Etape 2 : Configurer les variables d'environnement
# =============================================================================
$env:IMAGE_TAG = $ImageTag
$env:IMAGE_BACKEND = $ImageBackend
$env:IMAGE_FRONTEND = $ImageFrontend
$env:ACTIVE_COLOR = $currentColor

Write-Host "Configuration :" -ForegroundColor Cyan
Write-Host "  IMAGE_TAG      = $ImageTag"
Write-Host "  IMAGE_BACKEND  = $ImageBackend"
Write-Host "  IMAGE_FRONTEND = $ImageFrontend"
Write-Host ""

# =============================================================================
# Etape 3 : S'assurer que l'infrastructure de base est en cours d'execution
# =============================================================================
Write-Host "Demarrage de l'infrastructure de base..." -ForegroundColor Cyan

Set-Location $ProjectRoot
docker compose -f docker-compose.base.yml up -d postgres
Start-Sleep -Seconds 5

# Attendre que PostgreSQL soit pret
$maxRetries = 30
$retry = 0
while ($retry -lt $maxRetries) {
    $pgStatus = docker inspect --format='{{.State.Health.Status}}' postgres-db 2>$null
    if ($pgStatus -eq "healthy") {
        Write-Host "PostgreSQL est pret." -ForegroundColor Green
        break
    }
    Write-Host "Attente de PostgreSQL... ($retry/$maxRetries)"
    Start-Sleep -Seconds 2
    $retry++
}

if ($retry -ge $maxRetries) {
    Write-Host "ERREUR: PostgreSQL n'a pas demarre a temps." -ForegroundColor Red
    exit 1
}

# =============================================================================
# Etape 4 : Pull des nouvelles images
# =============================================================================
Write-Host ""
Write-Host "Telechargement des nouvelles images..." -ForegroundColor Cyan

docker pull "${ImageBackend}:${ImageTag}"
docker pull "${ImageFrontend}:${ImageTag}"

Write-Host "Images telechargees." -ForegroundColor Green

# =============================================================================
# Etape 5 : Deployer sur la couleur cible
# =============================================================================
Write-Host ""
Write-Host "Deploiement sur $targetColor..." -ForegroundColor Cyan

$targetComposeFile = "docker-compose.$targetColor.yml"
docker compose -f docker-compose.base.yml -f $targetComposeFile up -d "backend-$targetColor" "frontend-$targetColor"

# Attendre que les services soient prets
Write-Host "Attente du demarrage des services $targetColor..."
Start-Sleep -Seconds 10

# Verifier la sante du backend cible
$maxRetries = 30
$retry = 0
while ($retry -lt $maxRetries) {
    $backendStatus = docker inspect --format='{{.State.Health.Status}}' "backend-$targetColor" 2>$null
    if ($backendStatus -eq "healthy") {
        Write-Host "Backend $targetColor est pret." -ForegroundColor Green
        break
    }
    Write-Host "Attente du backend $targetColor... ($retry/$maxRetries)"
    Start-Sleep -Seconds 3
    $retry++
}

if ($retry -ge $maxRetries) {
    Write-Host "AVERTISSEMENT: Le backend $targetColor n'est pas healthy, mais on continue..." -ForegroundColor Yellow
}

# =============================================================================
# Etape 6 : Basculer le trafic vers la nouvelle couleur
# =============================================================================
Write-Host ""
Write-Host "Bascule du trafic vers $targetColor..." -ForegroundColor Cyan

# Mettre a jour la couleur active
$targetColor | Out-File -FilePath $activeColorFile -NoNewline -Encoding utf8
$env:ACTIVE_COLOR = $targetColor

# Redemarrer Nginx avec la nouvelle configuration
docker compose -f docker-compose.base.yml up -d nginx

# Recharger la configuration Nginx
Start-Sleep -Seconds 2
docker exec nginx-proxy nginx -s reload 2>$null

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  DEPLOIEMENT TERMINE AVEC SUCCES" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Couleur active : $targetColor" -ForegroundColor Green
Write-Host "Application accessible sur : http://localhost" -ForegroundColor Cyan
Write-Host ""
Write-Host "Pour rollback vers $currentColor :" -ForegroundColor Yellow
Write-Host "  .\scripts\rollback.ps1" -ForegroundColor Yellow
Write-Host ""

# =============================================================================
# Etape 7 : Afficher le statut final
# =============================================================================
Write-Host "Statut des conteneurs :" -ForegroundColor Cyan
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml -f docker-compose.green.yml ps
