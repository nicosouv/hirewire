# 🚀 Quick Start Guide - HireWire Web Application

## Option 1: Script automatique (Recommandé)

```bash
./scripts/start.sh
```

Puis ouvrez http://localhost:5173

## Option 2: Makefile

```bash
# Démarrer l'environnement de développement
make dev

# Voir les logs
make logs

# Arrêter
make stop
```

## Option 3: Docker Compose manuel

```bash
# 1. Démarrer PostgreSQL
docker-compose up -d postgres

# 2. Attendre que la DB soit prête (5 secondes)
sleep 5

# 3. Démarrer l'API
docker-compose up -d --build api

# 4. Démarrer le Frontend
docker-compose up -d --build frontend

# 5. Accéder à l'application
# Frontend: http://localhost:5173
# API Docs: http://localhost:8000/api/v1/docs
```

## Vérification

```bash
# Santé de l'API
curl http://localhost:8000/health

# Liste des companies (vide au début)
curl http://localhost:8000/api/v1/companies

# Voir les logs
docker-compose logs -f api frontend
```

## Créer votre première company via l'API

```bash
curl -X POST http://localhost:8000/api/v1/companies \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TechCorp",
    "industry": "Technology",
    "size": "500",
    "location": "Paris, France",
    "website": "https://techcorp.com"
  }'
```

## Architecture Simplifiée

```
┌─────────────────┐
│   Frontend      │  http://localhost:5173
│   (React +TS)   │
└────────┬────────┘
         │
         ▼ HTTP
┌─────────────────┐
│   API Backend   │  http://localhost:8000
│   (FastAPI)     │
└────────┬────────┘
         │
         ▼ SQL
┌─────────────────┐
│   PostgreSQL    │  port 5432
│                 │
└─────────────────┘
```

## Points d'entrée

| Service | URL | Description |
|---------|-----|-------------|
| Frontend | http://localhost:5173 | Interface utilisateur React |
| API | http://localhost:8000 | API REST FastAPI |
| API Docs | http://localhost:8000/api/v1/docs | Documentation Swagger interactive |
| PostgreSQL | localhost:5432 | Base de données (user: postgres, pass: password) |

## Commandes utiles

```bash
# Voir les logs de l'API seulement
make logs-api

# Redémarrer après un changement
make restart

# Rebuild après ajout de dépendances
make rebuild

# Shell dans l'API
make api-shell

# Shell dans le frontend
make frontend-shell

# Shell PostgreSQL
make db-shell

# Tout arrêter et nettoyer
make clean
```

## Workflow de développement

### Backend (FastAPI)

Les changements dans `backend/app/` sont automatiquement rechargés (hot reload).

```bash
# Éditer un fichier
vim backend/app/api/v1/endpoints/companies.py

# Le serveur se recharge automatiquement
# Vérifier les logs
make logs-api
```

### Frontend (React)

Les changements dans `frontend/src/` sont automatiquement rechargés par Vite.

```bash
# Éditer un composant
vim frontend/src/components/CompanyList.tsx

# Le navigateur se rafraîchit automatiquement
```

### Base de données

```bash
# Accéder à psql
make db-shell

# Voir les tables
\dt hirewire.*

# Voir les companies
SELECT * FROM hirewire.companies;
```

## Logique métier implémentée

✅ **Cascading Status Updates**

Quand vous changez le statut d'une interview, le statut du processus se met à jour automatiquement:

```python
# Dans backend/app/services/process_status_service.py

# Interview scheduled → Process devient "interviewing"
# Interview completed → Process reste "interviewing"
# Outcome added → Process devient "rejected"/"offer"/"accepted"
```

Exemple via API:

```bash
# 1. Créer un processus
POST /api/v1/processes
{
  "job_position_id": 1,
  "application_date": "2025-10-10",
  "status": "applied"
}

# 2. Ajouter une interview
POST /api/v1/interviews
{
  "process_id": 1,
  "interview_round": 1,
  "status": "scheduled",
  "scheduled_date": "2025-10-15"
}
# → Le processus passe automatiquement à "interviewing"

# 3. Marquer l'interview comme complétée
PUT /api/v1/interviews/1
{
  "status": "completed",
  "actual_date": "2025-10-15"
}
# → Le processus reste "interviewing"

# 4. Ajouter un outcome
POST /api/v1/outcomes
{
  "process_id": 1,
  "outcome": "offer",
  "outcome_date": "2025-10-20"
}
# → Le processus passe automatiquement à "offer"
```

## Intégration avec DBT

Le backend et DBT partagent la même base PostgreSQL:

```bash
# 1. Créer des données via l'UI/API
# (Les données vont dans hirewire.* tables)

# 2. Lancer les transformations DBT
make dbt-run

# 3. Les marts sont créés dans DuckDB
# (Disponibles pour Superset)
```

## Troubleshooting

### L'API ne démarre pas

```bash
# Vérifier les logs
make logs-api

# Vérifier que PostgreSQL est prêt
docker-compose exec postgres pg_isready

# Recreate le container
docker-compose up -d --force-recreate api
```

### Le frontend affiche une erreur de connexion

```bash
# Vérifier que l'API répond
curl http://localhost:8000/health

# Vérifier la config CORS dans backend/app/core/config.py
docker-compose exec api cat app/core/config.py
```

### Hot reload ne fonctionne pas

```bash
# Backend: vérifier le volume mount
docker-compose exec api ls -la /app/app

# Frontend: rebuild
docker-compose up -d --build frontend
```

## Production

Pour déployer en production:

```bash
# 1. Éditer .env avec les vraies valeurs
vim .env.prod

# 2. Build et démarrer
docker-compose -f docker-compose.prod.yml up -d

# 3. L'application est accessible via nginx
# http://your-domain.com
```

## Next Steps

1. ✅ L'application tourne en local
2. 📝 Lire `WEBAPP_QUICKSTART.md` pour la documentation complète
3. 🎨 Customiser le frontend dans `frontend/src/`
4. 🔧 Ajouter des endpoints dans `backend/app/api/v1/endpoints/`
5. 🧪 Écrire des tests dans `backend/tests/`
6. 🚀 Déployer en production avec `docker-compose.prod.yml`

## Support

- Documentation API: http://localhost:8000/api/v1/docs
- Documentation complète: `WEBAPP_QUICKSTART.md`
- Makefile commands: `make help`
