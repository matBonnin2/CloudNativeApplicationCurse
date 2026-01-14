# Plan de Deploiement Blue/Green

## Architecture Globale

```
                                    +-------------------+
                                    |    PostgreSQL     |
                                    |    (partage)      |
                                    +-------------------+
                                            |
                                            v
+----------+     +---------------+     +----------+
|  Client  | --> |  Nginx Proxy  | --> |   BLUE   | (frontend-blue + backend-blue)
+----------+     |   (port 80)   |     +----------+
                 |               |
                 |               |     +----------+
                 |               | --> |  GREEN   | (frontend-green + backend-green)
                 +---------------+     +----------+
```

## Fichiers Docker Compose

### Structure des fichiers

| Fichier | Role | Contenu |
|---------|------|---------|
| `docker-compose.base.yml` | Infrastructure partagee | PostgreSQL, Nginx reverse proxy |
| `docker-compose.blue.yml` | Instance Blue | frontend-blue, backend-blue |
| `docker-compose.green.yml` | Instance Green | frontend-green, backend-green |

### Pourquoi cette separation ?

1. **Independance** : On peut mettre a jour blue sans toucher green (et inversement)
2. **Base stable** : La DB et le proxy restent toujours actifs
3. **Idempotence** : Chaque `docker compose up` ne touche que les services concernes

## Mecanisme de Bascule

### Option choisie : Fichier de configuration dynamique

J'utilise une variable d'environnement `ACTIVE_COLOR` qui determine vers quel upstream Nginx route le trafic.

```
nginx/
├── nginx.conf           # Configuration principale
├── templates/
│   └── default.conf.template  # Template avec variable ACTIVE_COLOR
```

### Fonctionnement

1. **Deux upstreams definis** dans la config Nginx :
   - `upstream blue_backend { server backend-blue:3000; }`
   - `upstream blue_frontend { server frontend-blue:80; }`
   - `upstream green_backend { server backend-green:3000; }`
   - `upstream green_frontend { server frontend-green:80; }`

2. **Variable d'environnement** `ACTIVE_COLOR` (valeur : `blue` ou `green`)

3. **Template Nginx** utilise `envsubst` pour generer la config finale

4. **Bascule** = modifier `ACTIVE_COLOR` + `nginx -s reload`

### Avantages de cette approche

- **Zero downtime** : Nginx recharge sa config sans interruption
- **Rollback instantane** : Changer `ACTIVE_COLOR` et recharger
- **Simple** : Une seule variable a modifier

## Scenario de Deploiement

### Etat initial

```
ACTIVE_COLOR=blue
Blue  : EN PRODUCTION (recoit le trafic)
Green : INACTIVE (peut etre arretee ou ancienne version)
```

### Deploiement d'une nouvelle version

#### Etape 1 : Determiner la couleur cible

```powershell
# Lire la couleur active actuelle
$currentColor = Get-Content .active_color
# Determiner la cible
$targetColor = if ($currentColor -eq "blue") { "green" } else { "blue" }
```

#### Etape 2 : Deployer sur la couleur inactive

```powershell
# Deployer green (nouvelle version)
docker compose -f docker-compose.base.yml -f docker-compose.green.yml up -d backend-green frontend-green
```

- Blue continue de recevoir le trafic
- Green demarre avec la nouvelle version
- Aucune interruption de service

#### Etape 3 : Verifier la nouvelle version (optionnel)

```powershell
# Test de sante sur green
curl http://localhost:3001/api/health  # Port interne green
```

#### Etape 4 : Basculer le trafic

```powershell
# Changer la couleur active
"green" | Out-File -FilePath .active_color -NoNewline

# Regenerer la config Nginx et recharger
docker compose -f docker-compose.base.yml up -d nginx
docker exec nginx nginx -s reload
```

- Le trafic bascule instantanement vers green
- Blue reste active (pour rollback)

#### Etape 5 : Rollback (si necessaire)

```powershell
# Revenir a blue
"blue" | Out-File -FilePath .active_color -NoNewline
docker exec nginx nginx -s reload
```

- **Temps de rollback : < 1 seconde**

### Diagramme de sequence

```
Temps   |  Blue       |  Green      |  Trafic vers
--------|-------------|-------------|---------------
  T0    |  v1.0 (UP)  |  (DOWN)     |  Blue
  T1    |  v1.0 (UP)  |  v1.1 (UP)  |  Blue         <- Deploy green
  T2    |  v1.0 (UP)  |  v1.1 (UP)  |  Green        <- Bascule
  T3    |  v1.0 (UP)  |  v1.1 (UP)  |  Blue         <- Rollback (si besoin)
  T4    |  (DOWN)     |  v1.1 (UP)  |  Green        <- Cleanup blue (optionnel)
```

## Commandes Principales

### Lancer l'infrastructure complete

```powershell
# Premier deploiement (blue actif par defaut)
docker compose -f docker-compose.base.yml -f docker-compose.blue.yml up -d
```

### Deployer une nouvelle version sur green

```powershell
docker compose -f docker-compose.base.yml -f docker-compose.green.yml up -d backend-green frontend-green
```

### Basculer vers green

```powershell
$env:ACTIVE_COLOR = "green"
docker compose -f docker-compose.base.yml up -d nginx
```

### Rollback vers blue

```powershell
$env:ACTIVE_COLOR = "blue"
docker compose -f docker-compose.base.yml up -d nginx
```

### Arreter une couleur (cleanup optionnel)

```powershell
docker compose -f docker-compose.blue.yml down
```

## Stockage de la Couleur Active

La couleur active est stockee de deux facons :

1. **Fichier `.active_color`** : fichier texte contenant `blue` ou `green`
2. **Variable d'environnement `ACTIVE_COLOR`** : utilisee par Docker Compose

Le fichier `.active_color` sert de source de verite persistante.

## Integration CI/CD

Le pipeline CI determine automatiquement :

1. **Quelle est la couleur active** (lecture de `.active_color`)
2. **Sur quelle couleur deployer** (l'opposee)
3. **Quand basculer** (apres verification que la nouvelle version est healthy)

Voir le fichier `.github/workflows/ci.yml` pour l'implementation complete.

## Points importants

1. **La base de donnees est partagee** : Blue et Green utilisent le meme PostgreSQL
2. **Migrations de DB** : A executer AVANT le deploiement (compatibilite ascendante requise)
3. **Sessions utilisateur** : Utiliser un store externe (Redis) si sessions persistantes necessaires
4. **Les deux versions peuvent coexister** : Pas de conflit de ports grace aux noms de services distincts
