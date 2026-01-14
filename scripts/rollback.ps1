# =============================================================================
# Script de Rollback Blue/Green
# Usage: .\scripts\rollback.ps1
# Bascule instantanement vers la couleur inactive
# =============================================================================

param(
    [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  ROLLBACK BLUE/GREEN" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# =============================================================================
# Etape 1 : Lire la couleur active actuelle
# =============================================================================
$activeColorFile = Join-Path $ProjectRoot ".active_color"

if (-not (Test-Path $activeColorFile)) {
    Write-Host "ERREUR: Fichier .active_color non trouve." -ForegroundColor Red
    exit 1
}

$currentColor = (Get-Content $activeColorFile -Raw).Trim()
$targetColor = if ($currentColor -eq "blue") { "green" } else { "blue" }

Write-Host ""
Write-Host "Couleur active actuelle : $currentColor" -ForegroundColor Yellow
Write-Host "Rollback vers           : $targetColor" -ForegroundColor Green
Write-Host ""

# =============================================================================
# Etape 2 : Verifier que la couleur cible est disponible
# =============================================================================
$backendContainer = "backend-$targetColor"
$backendRunning = docker ps --format "{{.Names}}" | Where-Object { $_ -eq $backendContainer }

if (-not $backendRunning) {
    Write-Host "ERREUR: Le conteneur $backendContainer n'est pas en cours d'execution." -ForegroundColor Red
    Write-Host "Impossible de faire un rollback vers une version non deployee." -ForegroundColor Red
    exit 1
}

Write-Host "Conteneur $backendContainer trouve et en cours d'execution." -ForegroundColor Green

# =============================================================================
# Etape 3 : Basculer le trafic
# =============================================================================
Write-Host ""
Write-Host "Bascule du trafic vers $targetColor..." -ForegroundColor Cyan

# Mettre a jour la couleur active
Set-Location $ProjectRoot
$targetColor | Out-File -FilePath $activeColorFile -NoNewline -Encoding utf8
$env:ACTIVE_COLOR = $targetColor

# Redemarrer Nginx avec la nouvelle configuration
docker compose -f docker-compose.base.yml up -d nginx

# Recharger la configuration Nginx
Start-Sleep -Seconds 1
docker exec nginx-proxy nginx -s reload 2>$null

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ROLLBACK TERMINE" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Couleur active : $targetColor" -ForegroundColor Green
Write-Host "Temps de rollback : < 2 secondes" -ForegroundColor Cyan
Write-Host ""

# Afficher le statut
Write-Host "Statut des conteneurs :" -ForegroundColor Cyan
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml -f docker-compose.green.yml ps
