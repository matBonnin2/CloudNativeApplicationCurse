# Suivi des actions à faire (TP Cloud-Native)

Ce document liste **tout ce qu'il reste à faire** pour que le livrable soit complet et cohérent avec l'énoncé.

## Priorité critique (bloque la validation)

- [ ] Aligner le routing `/api` avec les routes backend
  - [ ] Choisir l'approche :
    - [ ] **Option A** : ajouter `StripPrefix(/api)` dans `docker-compose.yaml` pour que `/api/health` et `/api/whoami` arrivent sur `/health` et `/whoami`.
    - [ ] **Option B** : déplacer les routes backend vers `/api/health` et `/api/whoami` (et adapter la CI + tests).
  - [ ] Mettre à jour `docker-compose.yaml` en cohérence avec le choix.
  - [ ] Vérifier les routes via Traefik : `GET /api/health` et `GET /api/whoami`.

- [ ] Ajouter le job **publish** (TP 2.3) dans `.github/workflows/ci.yml`
  - [ ] Login GHCR avec `GITHUB_TOKEN` ou `CR_PAT`.
  - [ ] Tagger les images :
    - [ ] `ghcr.io/<user>/<repo>-backend:<sha>`
    - [ ] `ghcr.io/<user>/<repo>-frontend:<sha>`
  - [ ] Pousser les tags SHA pour toutes branches concernées.
  - [ ] Ajouter le tag `latest` uniquement sur `main`.

- [ ] Ajouter le déploiement automatisé (TP 3.1)
  - [ ] Déclencher le workflow sur `main`.
  - [ ] Créer un job (ou workflow séparé) qui fait :
    - [ ] `docker compose pull`
    - [ ] `docker compose up -d`
  - [ ] Documenter l'environnement de déploiement (runner, hôte cible, répertoire).

- [ ] Rendre `.dockerignore` versionné
  - [ ] Retirer `.dockerignore` du `.gitignore`.
  - [ ] Vérifier que `backend/.dockerignore` et `frontend/.dockerignore` sont suivis par Git.

## Priorité élevée (cohérence / exécution CI)

- [ ] Sécuriser la CI contre l'absence de `.env`
  - [ ] Créer un `.env.ci` dédié (versionné) **ou**
  - [ ] Générer `.env` en CI via secrets GitHub.
  - [ ] S'assurer que `POSTGRES_PASSWORD` est défini pour les tests.

- [ ] Aligner `.env.example` avec la configuration Docker
  - [ ] Harmoniser les valeurs `POSTGRES_USER/POSTGRES_PASSWORD/POSTGRES_DB`.
  - [ ] Aligner `DATABASE_URL` utilisé par le backend.
  - [ ] Mettre à jour `VITE_API_BASE_URL` pour pointer vers `/api` (via Traefik), pas `localhost:3000`.

## Bloc 1 – Runtime (Docker/Compose/Traefik)

- [ ] Vérifier que `docker-compose.yaml` respecte bien :
  - [ ] 4 services (traefik, frontend, backend, postgres).
  - [ ] 2 réseaux (`front_net`, `back_net`).
  - [ ] 1 volume nommé pour Postgres.
  - [ ] Aucun port exposé hors Traefik (ok si seul `:80` est publié).
  - [ ] Backend inaccessible en direct (pas de `ports` sur le service).

- [ ] Traefik
  - [ ] Provider docker activé.
  - [ ] EntryPoint HTTP `:80`.
  - [ ] Labels `PathPrefix(`/`)` et `PathPrefix(`/api`)` corrects.

## Bloc 1.6 – Scaling backend

- [ ] Route `/whoami` :
  - [ ] Retourne `hostname` (ou `INSTANCE_ID`).
  - [ ] Test en `docker compose up --scale backend=3`.
  - [ ] Capturer une preuve de round-robin dans les logs.

## Bloc 2 – CI (build + smoke tests)

- [ ] Job build (TP 2.1) :
  - [ ] Runner `self-hosted`.
  - [ ] Build des images `backend:ci-build` et `frontend:ci-build`.

- [ ] Job smoke-tests (TP 2.2) :
  - [ ] Utilise `docker-compose.ci.yaml`.
  - [ ] Test `GET /api/health` et `GET /api/whoami`.
  - [ ] Stoppe la stack (down -v).

## Bloc 3.2 – Dashboard Traefik (optionnel)

- [ ] Activer l'API + dashboard Traefik sur un entrypoint dédié.
- [ ] Router privé vers `api@internal`.
- [ ] Pas d'exposition publique (idéalement bind `127.0.0.1`).
- [ ] Vérifier l'affichage des services (frontend/backend) + scaling.

## Bloc 3.3 – Logs structurés

- [ ] Backend :
  - [ ] Logs structurés JSON/logfmt avec timestamp, method, route, status, duration, hostname, level.
  - [ ] Middleware qui log **entrée** + **sortie**.
  - [ ] Vérifier que chaque instance logue ses requêtes lors du scaling.

- [ ] Traefik :
  - [ ] Access logs actifs (format structuré).
  - [ ] Logs incluant router/service/code/duration.

- [ ] Vérification conjointe :
  - [ ] `Traefik -> backend -> Traefik` visible dans les logs.
  - [ ] Test répétitif sur `/api/whoami`.

## Documentation / Cohérence

- [ ] Mettre à jour `README.md` :
  - [ ] Accès via Traefik (`http://localhost/` + `/api`).
  - [ ] Retirer les ports directs 3000/8080.
  - [ ] Ajouter instructions CI (runner self-hosted, GHCR).
  - [ ] Ajouter preuves attendues (scaling, logs, images GHCR).

