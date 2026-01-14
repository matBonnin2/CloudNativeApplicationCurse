#!/usr/bin/env pwsh
# =============================================================================
# Script de deploiement automatique - CloudNativeApplicationCurse
# Ce script est appele automatiquement par GitHub Actions apres le push des images
# =============================================================================

param(
    [string]$ImageTag = $env:GITHUB_SHA,
    [string]$RepoOwner = "matbonnin2",
    [string]$RepoName = "cloudnativeapplicationcurse"
)

$ErrorActionPreference = "Stop"

# Variables
$IMAGE_BACKEND = "ghcr.io/$RepoOwner/$RepoName-backend"
$IMAGE_FRONTEND = "ghcr.io/$RepoOwner/$RepoName-frontend"

Write-Host "========================================"
Write-Host "  Deploiement automatique"
Write-Host "========================================"
Write-Host "Tag: $ImageTag"
Write-Host "Backend: $IMAGE_BACKEND"
Write-Host "Frontend: $IMAGE_FRONTEND"
Write-Host "========================================"

# Etape 1: Arreter les conteneurs en cours (sans supprimer les volumes)
Write-Host "`n[1/4] Arret des conteneurs existants..."
docker compose -f docker-compose.deploy.yaml down
if ($LASTEXITCODE -ne 0) {
    Write-Host "Avertissement: Aucun conteneur a arreter ou erreur mineure"
}

# Etape 2: Pull des nouvelles images depuis GHCR
Write-Host "`n[2/4] Telechargement des nouvelles images..."
docker pull "${IMAGE_BACKEND}:${ImageTag}"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec du pull de l'image backend"
    exit 1
}

docker pull "${IMAGE_FRONTEND}:${ImageTag}"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec du pull de l'image frontend"
    exit 1
}

# Etape 3: Definir les variables d'environnement pour docker-compose
Write-Host "`n[3/4] Configuration des variables d'environnement..."
$env:IMAGE_TAG = $ImageTag
$env:IMAGE_BACKEND = $IMAGE_BACKEND
$env:IMAGE_FRONTEND = $IMAGE_FRONTEND

# Etape 4: Demarrer l'environnement complet
Write-Host "`n[4/4] Demarrage de l'application..."
docker compose -f docker-compose.deploy.yaml up -d
if ($LASTEXITCODE -ne 0) {
    Write-Error "Echec du demarrage des conteneurs"
    exit 1
}

Write-Host "`n========================================"
Write-Host "  Deploiement termine avec succes!"
Write-Host "========================================"
Write-Host "Application accessible sur http://localhost"

# Afficher l'etat des conteneurs
Write-Host "`nEtat des conteneurs:"
docker compose -f docker-compose.deploy.yaml ps
