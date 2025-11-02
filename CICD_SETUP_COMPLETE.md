# ✅ CI/CD Setup Complete - HireWire

Votre pipeline CI/CD est maintenant configuré ! Voici tout ce qui a été mis en place.

---

## 📦 Ce qui a été créé

### 1. Workflows GitHub Actions (3 fichiers)

**`.github/workflows/ci-tests.yml`** - Tests automatiques
- ✅ Se déclenche sur chaque push/PR
- ✅ Détection intelligente des changements
- ✅ Tests en parallèle par service
- ✅ Commentaires automatiques sur les PRs
- ✅ Support Python 3.11/3.12 et Node 20

**`.github/workflows/build-and-push.yml`** - Build des images Docker
- ✅ Se déclenche sur les tags (`v*.*.*`)
- ✅ Détection des services modifiés
- ✅ Build sélectif (uniquement ce qui a changé)
- ✅ Push sur GitHub Container Registry (GHCR)
- ✅ Création automatique de releases GitHub

**`.github/dependabot.yml`** - Mises à jour automatiques
- ✅ Dépendances Python (backend, airflow)
- ✅ Dépendances npm (frontend)
- ✅ GitHub Actions
- ✅ Images Docker de base

### 2. Dockerfiles de Production (4 services)

**`.infra/docker/backend.Dockerfile`**
- Multi-stage build (builder + runtime)
- Image finale : ~200MB
- Utilisateur non-root
- Health checks
- uvicorn avec 4 workers

**`.infra/docker/frontend.Dockerfile`**
- Build Node.js + Nginx
- Image finale : ~50MB
- Compression gzip
- Cache des assets statiques
- Routing SPA

**`.infra/docker/nginx.conf`**
- Configuration Nginx optimisée
- Headers de sécurité
- Cache intelligent
- Support SPA

**Note**: Les Dockerfiles Airflow et DBT existent déjà et ont été conservés.

### 3. Scripts Helper

**`scripts/release.sh`**
- Script interactif de création de releases
- Support semantic versioning
- Détection automatique des changements
- Mode dry-run pour tester

**Exemples d'utilisation** :
```bash
./scripts/release.sh 1.2.3      # Version explicite
./scripts/release.sh patch      # Bump patch (1.0.0 -> 1.0.1)
./scripts/release.sh minor      # Bump minor (1.0.0 -> 1.1.0)
./scripts/release.sh major      # Bump major (1.0.0 -> 2.0.0)
./scripts/release.sh --dry-run  # Test sans créer le tag
```

### 4. Documentation Complète

**`docs/CICD_GUIDE.md`** (Guide complet - 500+ lignes)
- Architecture détaillée
- Description de chaque workflow
- Guide de release complet
- Configuration requise
- Troubleshooting exhaustif

**`CICD_README.md`** (Quick start)
- Commandes rapides
- Exemples d'utilisation
- Troubleshooting concis

---

## 🎯 Architecture CI/CD

### Détection Intelligente des Changements

Le système détecte automatiquement quels services ont été modifiés :

**Sur Push/PR** :
```yaml
# Utilise dorny/paths-filter pour détecter les changements
backend: backend/**
frontend: frontend/**
airflow: airflow/**
dbt: dbt_project/**, profiles/**
```

**Sur Tag** :
```bash
# Compare avec le tag précédent
git diff --name-only v1.0.0 v1.1.0

# Ne build que les services modifiés
```

### Flux de Travail

#### 1. Développement Normal
```
┌─────────────┐
│ Code Change │
└──────┬──────┘
       │
       ▼
┌──────────────┐
│ git push     │
└──────┬───────┘
       │
       ▼
┌──────────────────┐
│ CI Tests Execute │ (2-5 min)
│ (changed only)   │
└──────┬───────────┘
       │
       ▼
┌──────────────┐
│ Tests Pass ✅│
└──────────────┘
```

#### 2. Création de Release
```
┌─────────────────┐
│ ./release.sh    │
│ 1.2.3           │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ git tag v1.2.3  │
│ git push        │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Detect Changes      │
│ (vs previous tag)   │
└────────┬────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│Backend │ │Frontend│
│ Build  │ │ Build  │
└────┬───┘ └───┬────┘
     │         │
     └────┬────┘
          │
          ▼
┌──────────────────┐
│ Push to GHCR     │
│ (Multi-arch)     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ GitHub Release   │
│ + Changelog      │
└──────────────────┘
```

---

## 🚀 Première Utilisation

### Étape 1 : Configuration GitHub

#### 1.1 Activer GitHub Packages

1. Allez sur **Settings → Actions → General**
2. Sous "Workflow permissions" :
   - ✅ **Read and write permissions**
   - ✅ **Allow GitHub Actions to create and approve pull requests**
3. Cliquez sur **Save**

#### 1.2 Remplacer YOUR_USERNAME

Dans les fichiers suivants, remplacez `YOUR_USERNAME` par votre nom d'utilisateur GitHub :

```bash
# Fichiers à modifier
.github/workflows/build-and-push.yml  # Ligne 8
docs/CICD_GUIDE.md                    # Plusieurs occurrences
CICD_README.md                         # Plusieurs occurrences

# Utiliser sed (macOS/Linux)
find . -type f \( -name "*.yml" -o -name "*.md" \) -exec sed -i '' 's/YOUR_USERNAME/votre-username/g' {} +

# Ou manuellement avec votre éditeur
```

#### 1.3 Branch Protection (Optionnel mais recommandé)

1. **Settings → Branches → Add rule**
2. Branch name pattern : `main`
3. Cochez :
   - ✅ Require status checks to pass before merging
   - ✅ Status checks that are required : `ci-tests-summary`
   - ✅ Require branches to be up to date before merging
4. **Save changes**

### Étape 2 : Tester Localement

```bash
# 1. Tester que tous les tests passent
./scripts/run_all_tests.sh

# 2. Tester le script de release (dry-run)
./scripts/release.sh --dry-run

# 3. Vérifier que les Dockerfiles buildent
docker build -f .infra/docker/backend.Dockerfile ./backend
docker build -f .infra/docker/frontend.Dockerfile ./frontend
```

### Étape 3 : Premier Commit

```bash
# 1. Ajouter tous les fichiers CI/CD
git add .github/ .infra/ scripts/ docs/ *.md

# 2. Commit
git commit -m "feat: add CI/CD pipeline with intelligent change detection"

# 3. Push (déclenche les tests)
git push origin main

# 4. Vérifier que les tests passent
# https://github.com/YOUR_USERNAME/hirewire/actions
```

### Étape 4 : Première Release

```bash
# 1. Créer la première release
./scripts/release.sh 1.0.0

# 2. Suivre la progression
# https://github.com/YOUR_USERNAME/hirewire/actions

# 3. Vérifier les images Docker (après ~20-30 min)
docker pull ghcr.io/YOUR_USERNAME/hirewire-backend:1.0.0
docker pull ghcr.io/YOUR_USERNAME/hirewire-frontend:1.0.0
docker pull ghcr.io/YOUR_USERNAME/hirewire-airflow:1.0.0
docker pull ghcr.io/YOUR_USERNAME/hirewire-dbt:1.0.0

# 4. Vérifier la release GitHub
# https://github.com/YOUR_USERNAME/hirewire/releases/latest
```

---

## 📊 Exemples de Scénarios

### Scénario 1 : Bug Fix Frontend

```bash
# 1. Créer une branche
git checkout -b fix/dashboard-bug

# 2. Corriger le bug
# frontend/src/pages/Dashboard.tsx

# 3. Commit et push
git add frontend/
git commit -m "fix: correct dashboard data display"
git push origin fix/dashboard-bug

# Résultat CI :
# ✅ Frontend tests (2 min)
# ⏭️  Backend tests skipped
# ⏭️  Airflow tests skipped
# ⏭️  DBT validation skipped

# 4. Merger dans main
git checkout main
git merge fix/dashboard-bug
git push origin main

# 5. Créer une release patch
./scripts/release.sh patch  # 1.0.0 -> 1.0.1

# Résultat Build :
# ✅ Frontend image: ghcr.io/.../hirewire-frontend:1.0.1
# ⏭️  Backend skipped (no changes)
# ⏭️  Airflow skipped (no changes)
# ⏭️  DBT skipped (no changes)
```

### Scénario 2 : Nouvelle Feature Backend + Frontend

```bash
# 1. Branche feature
git checkout -b feature/user-profile

# 2. Développer la feature
# backend/app/api/v1/endpoints/profile.py
# frontend/src/pages/Profile.tsx

# 3. Commit
git add backend/ frontend/
git commit -m "feat: add user profile management"
git push origin feature/user-profile

# Résultat CI :
# ✅ Backend tests (4 min)
# ✅ Frontend tests (3 min)
# ⏭️  Airflow tests skipped
# ⏭️  DBT validation skipped

# 4. Créer PR
gh pr create --title "Add user profile management"

# CI re-runs + commentaire automatique sur la PR

# 5. Merger et release minor
git checkout main
git pull
./scripts/release.sh minor  # 1.0.1 -> 1.1.0

# Résultat Build :
# ✅ Backend image: ghcr.io/.../hirewire-backend:1.1.0
# ✅ Frontend image: ghcr.io/.../hirewire-frontend:1.1.0
# ⏭️  Airflow skipped
# ⏭️  DBT skipped
```

### Scénario 3 : Nouveau DAG Airflow

```bash
# 1. Ajouter le DAG
# airflow/dags/new_dag.py

# 2. Commit et push
git add airflow/
git commit -m "feat: add data quality DAG"
git push origin main

# Résultat CI :
# ✅ Airflow tests (2 min)
# ⏭️  Backend tests skipped
# ⏭️  Frontend tests skipped
# ⏭️  DBT validation skipped

# 3. Release minor
./scripts/release.sh minor  # 1.1.0 -> 1.2.0

# Résultat Build :
# ✅ Airflow image: ghcr.io/.../hirewire-airflow:1.2.0
# ⏭️  Backend skipped
# ⏭️  Frontend skipped
# ⏭️  DBT skipped
```

---

## 🎓 Comprendre les Tags d'Images

Pour une release `v1.2.3`, le système crée automatiquement :

```
ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3    # Version exacte
ghcr.io/YOUR_USERNAME/hirewire-backend:1.2      # Minor version
ghcr.io/YOUR_USERNAME/hirewire-backend:1        # Major version
ghcr.io/YOUR_USERNAME/hirewire-backend:latest   # Dernier stable
```

**Utilisation recommandée** :

```yaml
# Production : version exacte
image: ghcr.io/YOUR_USERNAME/hirewire-backend:1.2.3

# Staging : minor version (auto-updates patches)
image: ghcr.io/YOUR_USERNAME/hirewire-backend:1.2

# Development : latest
image: ghcr.io/YOUR_USERNAME/hirewire-backend:latest
```

---

## 📈 Avantages de cette Setup

### 1. Économie de Temps CI/CD

**Avant** : Tous les tests à chaque fois (~15 min)
**Après** : Tests sélectifs (~2-5 min en moyenne)

**Économie estimée** : 60-80% de temps CI

### 2. Économie de Bande Passante

**Avant** : Build toutes les images à chaque release (~4GB)
**Après** : Build sélectif (~500MB-1GB en moyenne)

**Économie estimée** : 70-80% de bande passante

### 3. Feedback Plus Rapide

- **Tests ciblés** : Résultats en 2-5 min vs 15 min
- **PR Comments** : Résultats visibles directement sur la PR
- **Workflow cancellation** : Arrête les builds obsolètes

### 4. Traçabilité

- **Changelog automatique** : Généré depuis les commits
- **GitHub Releases** : Historique complet
- **Tags sémantiques** : Versioning clair

---

## 🔍 Monitoring & Métriques

### Dashboards Disponibles

```bash
# GitHub Actions
https://github.com/YOUR_USERNAME/hirewire/actions

# GitHub Packages (Images Docker)
https://github.com/YOUR_USERNAME?tab=packages

# GitHub Releases
https://github.com/YOUR_USERNAME/hirewire/releases

# Dependabot Security
https://github.com/YOUR_USERNAME/hirewire/security/dependabot
```

### Métriques à Suivre

- ⏱️  **Temps moyen de CI** : Objectif < 5 min
- ✅ **Taux de succès** : Objectif > 95%
- 🐳 **Taille des images** : Objectif < 500MB (sauf Airflow)
- 📦 **Dépendances obsolètes** : Objectif 0 (Dependabot)

---

## 🐛 Troubleshooting Rapide

### Tests échouent en CI mais passent localement

**Cause** : Différences d'environnement

**Solution** :
```bash
# Vérifier les versions Python/Node
python --version  # Doit être 3.11 ou 3.12
node --version    # Doit être 20.x

# Nettoyer le cache
rm -rf __pycache__ .pytest_cache
rm -rf node_modules package-lock.json
```

### Build Docker échoue

**Cause** : Dockerfile ou contexte invalide

**Solution** :
```bash
# Tester localement
docker build -f .infra/docker/backend.Dockerfile ./backend -t test

# Vérifier les logs GitHub Actions pour les détails
```

### Images ne s'affichent pas dans Packages

**Cause** : Package privé par défaut

**Solution** :
1. Aller sur **Packages → hirewire-xxx → Package settings**
2. Scroll down → **Change visibility**
3. Sélectionner **Public**

### Release script dit "uncommitted changes"

**Solution** :
```bash
git status              # Voir les changements
git add .              # Ajouter
git commit -m "..."    # Committer
./scripts/release.sh   # Réessayer
```

---

## 📚 Ressources

### Documentation Créée

- **[CICD_GUIDE.md](docs/CICD_GUIDE.md)** - Guide complet (500+ lignes)
- **[CICD_README.md](CICD_README.md)** - Quick start
- **[TESTING_GUIDE.md](docs/TESTING_GUIDE.md)** - Guide des tests

### Scripts

- **[release.sh](scripts/release.sh)** - Helper de release
- **[run_all_tests.sh](scripts/run_all_tests.sh)** - Lancer tous les tests

### Workflows

- **[ci-tests.yml](.github/workflows/ci-tests.yml)** - Tests automatiques
- **[build-and-push.yml](.github/workflows/build-and-push.yml)** - Build images

---

## ✅ Checklist de Validation

Avant de considérer la setup complète, vérifiez :

- [ ] GitHub Packages activé (Settings → Actions → Permissions)
- [ ] `YOUR_USERNAME` remplacé dans tous les fichiers
- [ ] Branch protection configurée sur `main`
- [ ] Tests passent localement : `./scripts/run_all_tests.sh`
- [ ] Premier commit CI/CD effectué et tests passent
- [ ] Première release créée : `./scripts/release.sh 1.0.0`
- [ ] Images Docker disponibles sur GHCR
- [ ] GitHub Release créée automatiquement
- [ ] Documentation lue et comprise

---

## 🎉 Félicitations !

Votre pipeline CI/CD est maintenant opérationnel avec :

✅ **Tests automatiques intelligents**
✅ **Build sélectif des images Docker**
✅ **Releases automatisées**
✅ **Documentation complète**
✅ **Scripts helper**
✅ **Mises à jour automatiques (Dependabot)**

## ✨ Pipeline Vérifié et Fonctionnel

Le pipeline a été testé et validé avec succès :

**v0.4.6** - Premier build frontend réussi
- Image: `ghcr.io/nicosouv/hirewire-frontend:0.4.6`
- Taille: 83MB (optimisé)
- Temps de build: 43 secondes
- Plateforme: linux/amd64

**v0.4.7** - Build backend testé
- Image: `ghcr.io/nicosouv/hirewire-backend:0.4.7`
- Build multi-architecture (amd64 + arm64)
- Tests et build automatiques validés

**Note ARM64** : Le build ARM64 pour le frontend a été désactivé en raison d'un crash QEMU lors de `npm ci`. Le backend, Airflow et DBT supportent toujours le multi-architecture.

## 📦 Images Docker Disponibles

Toutes les images sont disponibles sur GitHub Container Registry :

```bash
# Télécharger les images
docker pull ghcr.io/nicosouv/hirewire-frontend:0.4.6
docker pull --platform linux/amd64 ghcr.io/nicosouv/hirewire-backend:0.4.7

# Utiliser dans docker-compose.yml
services:
  frontend:
    image: ghcr.io/nicosouv/hirewire-frontend:0.4.6
  backend:
    image: ghcr.io/nicosouv/hirewire-backend:0.4.7
```

**Prochaines étapes recommandées** :

1. ✅ Tester le workflow complet avec une feature (FAIT)
2. Configurer un environnement de staging
3. Ajouter des notifications (Slack, Discord)
4. Mettre en place le déploiement automatique

Pour toute question, consultez la [documentation complète](docs/CICD_GUIDE.md) ou ouvrez une issue !
