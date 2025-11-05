# HireWire Documentation

Documentation complète pour le projet HireWire - Plateforme d'analyse d'entretiens d'embauche.

## 📚 Table des Matières

### Quick Start

- **[QUICKSTART.md](QUICKSTART.md)** - Guide de démarrage rapide
  - Installation et configuration initiale
  - Premiers pas avec l'application

### Architecture & Stack

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Architecture globale du système
  - Vue d'ensemble technique
  - Diagrammes et flux de données

- **[DATA_PIPELINE.md](DATA_PIPELINE.md)** - Pipeline de données
  - PostgreSQL → DBT → DuckDB → Superset
  - ETL et transformations
  - Star schema et modèles DBT

### Application Web

- **[WEB_APP.md](WEB_APP.md)** - Application web (Frontend + Backend)
  - Architecture React + FastAPI
  - Composants principaux
  - State management et routing

- **[FRONTEND.md](FRONTEND.md)** - Documentation frontend détaillée
  - React + TypeScript
  - TanStack Query
  - Tailwind CSS

- **[WEBAPP_QUICKSTART.md](WEBAPP_QUICKSTART.md)** - Quick start web app
  - Configuration
  - Utilisation

- **[UX_REDESIGN.md](UX_REDESIGN.md)** - Redesign UX
  - Améliorations d'interface
  - Design system

### Airflow & Orchestration

- **[AIRFLOW.md](AIRFLOW.md)** - Apache Airflow configuration
  - Setup et configuration
  - DAGs disponibles

- **[AIRFLOW_AUTH.md](AIRFLOW_AUTH.md)** - Authentification Airflow
  - Sécurité et accès
  - JWT validation

- **[AIRFLOW_TESTING.md](AIRFLOW_TESTING.md)** - Tests Airflow
  - Test des DAGs
  - Validation des workflows

### Exports & Fonctionnalités

- **[EXPORTS.md](EXPORTS.md)** - Système d'export
  - Génération de rapports Excel/CSV
  - Envoi par email via SMTP
  - Configuration et troubleshooting

### CI/CD & Déploiement

#### Tests Unifiés (Nouveau! ⭐)

- **[CICD_SUMMARY.md](CICD_SUMMARY.md)** ⭐ **COMMENCER ICI** - Résumé CI/CD unifié
  - Une seule source de vérité: `build.sh`
  - Mêmes commandes en local et dans la CI
  - 47% de réduction du code YAML
  - Guide de migration en 4 semaines

- **[CICD_UNIFIED_TESTS.md](CICD_UNIFIED_TESTS.md)** - Guide complet des tests unifiés
  - Architecture et motivation
  - Utilisation de `build.sh`
  - Migration depuis l'ancienne approche
  - FAQ et troubleshooting

- **[CICD_MIGRATION_COMPARISON.md](CICD_MIGRATION_COMPARISON.md)** - Comparaison Avant/Après
  - Analyse détaillée des changements
  - Métriques et statistiques
  - Réduction de la complexité
  - Exemples concrets

- **[CICD_ACTION_PLAN.md](CICD_ACTION_PLAN.md)** - Plan d'action migration
  - Timeline de 4 semaines
  - Validation en parallèle
  - Critères de succès
  - Plan de rollback

#### CI/CD Legacy

- **[CICD_QUICKREF.md](CICD_QUICKREF.md)** - Quick reference CI/CD
  - Commandes rapides
  - Workflow overview

- **[CICD_GUIDE.md](CICD_GUIDE.md)** - Guide complet CI/CD (700+ lignes)
  - Architecture détaillée
  - Workflows GitHub Actions
  - Build Docker et releases
  - Setup et validation
  - Scénarios d'utilisation
  - Troubleshooting

#### Déploiement

- **[PRODUCTION_DEPLOYMENT.md](PRODUCTION_DEPLOYMENT.md)** - Déploiement production
  - Utilisation des images GHCR
  - Configuration production
  - Sécurité et monitoring
  - Backup et maintenance
  - Déploiement cloud (AWS, GCP, Azure)

### Testing

- **[TESTING_QUICKREF.md](TESTING_QUICKREF.md)** - Quick reference tests
  - Commandes rapides pour lancer les tests

- **[TESTING_GUIDE.md](TESTING_GUIDE.md)** - Guide complet des tests
  - Backend: pytest + FastAPI TestClient
  - Frontend: Vitest + React Testing Library + Playwright
  - Airflow: DAG validation
  - E2E: Playwright tests

## 🗂️ Organisation des Fichiers

```
docs/
├── README.md                       # Ce fichier (index)
├── QUICKSTART.md                   # Démarrage rapide
├── ARCHITECTURE.md                 # Architecture système
├── DATA_PIPELINE.md                # Pipeline ETL/DBT
├── WEB_APP.md                      # Application web
├── FRONTEND.md                     # Frontend React
├── WEBAPP_QUICKSTART.md            # Quick start web app
├── UX_REDESIGN.md                  # Redesign UX
├── AIRFLOW.md                      # Airflow setup
├── AIRFLOW_AUTH.md                 # Airflow auth
├── AIRFLOW_TESTING.md              # Airflow tests
├── EXPORTS.md                      # Système d'export
├── GAMIFICATION_AUDIT.md           # Audit gamification
├── CICD_SUMMARY.md                 # ⭐ CI/CD unifié (START HERE)
├── CICD_UNIFIED_TESTS.md           # Guide complet tests unifiés
├── CICD_MIGRATION_COMPARISON.md    # Comparaison Avant/Après
├── CICD_ACTION_PLAN.md             # Plan de migration 4 semaines
├── CICD_FIXES.md                   # Corrections erreurs CI
├── CICD_QUICKREF.md                # CI/CD quick ref (legacy)
├── CICD_GUIDE.md                   # CI/CD complet (legacy)
├── PRODUCTION_DEPLOYMENT.md        # Déploiement prod
├── TESTING_QUICKREF.md             # Tests quick ref
├── TESTING_GUIDE.md                # Tests complet
├── FRONTEND_VITEST_SETUP.md        # Setup Vitest frontend
└── SESSION_RECAP_2025-01-12.md     # Récap session 12 jan 2025
```

## 🔗 Liens Utiles

### GitHub

- **Repository**: https://github.com/nicosouv/hirewire
- **Packages (GHCR)**: https://github.com/nicosouv?tab=packages
- **Releases**: https://github.com/nicosouv/hirewire/releases
- **Actions (CI/CD)**: https://github.com/nicosouv/hirewire/actions

### Services Locaux

- **Frontend**: http://localhost:5173
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Airflow**: http://localhost:8081 (via JWT auth)

## 📦 Images Docker

Images pré-construites disponibles sur GitHub Container Registry :

```bash
# Frontend (amd64)
docker pull ghcr.io/nicosouv/hirewire-frontend:latest

# Backend (amd64 + arm64)
docker pull ghcr.io/nicosouv/hirewire-backend:latest

# Airflow
docker pull ghcr.io/nicosouv/hirewire-airflow:latest

# DBT
docker pull ghcr.io/nicosouv/hirewire-dbt:latest
```

## 🛠️ Stack Technique

- **Frontend**: React 19 + TypeScript + TailwindCSS + Vite
- **Backend**: FastAPI + Python 3.11 + PostgreSQL
- **Data**: DBT + DuckDB + Apache Superset
- **Orchestration**: Apache Airflow 3.x
- **CI/CD**: GitHub Actions + Docker + GHCR
- **Testing**: pytest, Vitest, Playwright

## 📝 Maintenance

Ce README est l'index principal de la documentation. Pour contribuer :

1. Ajouter les nouveaux docs dans `docs/`
2. Mettre à jour cet index avec la description
3. Maintenir les liens à jour

---

**Dernière mise à jour**: 12 janvier 2025 - v0.4.7+

### 🆕 Nouveautés (12 janvier 2025)

**Tests CI/CD Unifiés + Vitest Frontend** - Refonte complète de l'approche testing:
- ✅ Une seule source de vérité pour tous les tests (`build.sh`)
- ✅ Mêmes commandes en local et dans la CI
- ✅ 47% de réduction du code YAML (150 → 80 lignes)
- ✅ Vitest configuré pour le frontend (9/11 tests passing)
- ✅ Erreurs CI backend/frontend corrigées
- ✅ 7 documents de documentation créés
- 📖 Voir [CICD_SUMMARY.md](CICD_SUMMARY.md) pour commencer
- 📖 Voir [SESSION_RECAP_2025-01-12.md](SESSION_RECAP_2025-01-12.md) pour le récap complet
