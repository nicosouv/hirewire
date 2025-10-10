# HireWire Web Application

Interface web moderne pour gérer vos entretiens d'embauche avec FastAPI (backend) et React TypeScript (frontend).

## Architecture

```
├── backend/          # FastAPI + SQLAlchemy + PostgreSQL
│   ├── app/
│   │   ├── api/     # Endpoints REST
│   │   ├── models/  # Modèles SQLAlchemy
│   │   ├── schemas/ # Schémas Pydantic
│   │   ├── services/# Logique métier (cascading updates)
│   │   └── core/    # Configuration
│   ├── Dockerfile         # Production
│   └── Dockerfile.dev     # Développement
│
├── frontend/         # React + TypeScript + Vite
│   ├── src/
│   ├── Dockerfile         # Production (nginx)
│   └── Dockerfile.dev     # Développement
│
└── nginx/            # Reverse proxy pour production
```

## Démarrage rapide

### Développement local

```bash
# 1. Démarrer tous les services (DB + API + Frontend)
docker-compose up -d postgres api frontend

# 2. Accéder à l'application
# Frontend: http://localhost:5173
# API: http://localhost:8000
# API Docs: http://localhost:8000/api/v1/docs

# 3. Voir les logs
docker-compose logs -f api
docker-compose logs -f frontend
```

### Production

```bash
# 1. Configurer les variables d'environnement
cp .env.example .env
# Éditer .env avec vos valeurs de production

# 2. Build et démarrage
docker-compose -f docker-compose.prod.yml up -d

# 3. L'application est accessible via nginx
# http://localhost (port 80)
# https://localhost (port 443 si SSL configuré)
```

## Services

### Backend (FastAPI)
- **Port**: 8000
- **Documentation**: `/api/v1/docs` (Swagger UI)
- **Health check**: `/health`
- **Hot reload**: Activé en dev avec volume mount

### Frontend (React)
- **Port**: 5173 (dev), 80 (prod via nginx)
- **Hot reload**: Activé en dev avec Vite
- **Build optimisé**: Multi-stage Docker build pour production

### Base de données
- **PostgreSQL**: Port 5432
- **Schema**: `hirewire`
- **Migrations**: Alembic (à venir)

## Fonctionnalités

### Logique métier implémentée

1. **Cascading Status Updates** (`backend/app/services/process_status_service.py`)
   - Mise à jour automatique du statut du processus quand:
     - Une interview change de statut
     - Un outcome est ajouté
     - Une interview passée est marquée comme complétée

2. **Règles de cohérence**
   - Un seul outcome par processus
   - Rounds d'interview séquentiels
   - Dates logiques (interview après application, outcome après interviews)

3. **API REST complète**
   - CRUD pour: Companies, Positions, Processes, Interviews, Outcomes
   - Endpoints dashboard pour statistiques
   - Validation avec Pydantic
   - Documentation auto-générée

## Développement

### Structure du backend

```
app/
├── api/v1/endpoints/    # Endpoints par ressource
│   ├── companies.py
│   ├── interview_processes.py
│   ├── interviews.py
│   ├── outcomes.py
│   └── dashboard.py
├── models/              # SQLAlchemy models
├── schemas/             # Pydantic schemas
├── services/            # Business logic
│   └── process_status_service.py  # Cascading updates
└── core/
    ├── config.py        # Configuration
    └── security.py      # Auth (à venir)
```

### Ajouter un endpoint

1. Créer le schéma dans `schemas/`
2. Ajouter la route dans `api/v1/endpoints/`
3. Implémenter la logique métier dans `services/`

### Exemple - Créer une company

```bash
curl -X POST http://localhost:8000/api/v1/companies \
  -H "Content-Type: application/json" \
  -d '{
    "name": "TechCorp",
    "industry": "Technology",
    "size": "500",
    "location": "Paris"
  }'
```

## Commandes utiles

```bash
# Backend - Démarrage manuel
cd backend
python -m uvicorn app.main:app --reload

# Frontend - Démarrage manuel
cd frontend
npm run dev

# Tests backend
docker-compose exec api pytest

# Voir logs API
docker-compose logs -f api

# Rebuild après changement de dépendances
docker-compose up -d --build api

# Shell dans le container API
docker-compose exec api bash

# Shell dans le container frontend
docker-compose exec frontend sh
```

## Configuration des environnements

### Développement (.env)
```env
DATABASE_URL=postgresql://postgres:password@postgres:5432/hirewire
DEBUG=True
BACKEND_CORS_ORIGINS=["http://localhost:5173"]
```

### Production (.env.prod)
```env
DATABASE_URL=postgresql://user:strongpassword@postgres:5432/hirewire
DEBUG=False
SECRET_KEY=<généré avec openssl rand -hex 32>
BACKEND_CORS_ORIGINS=["https://yourdomain.com"]
```

## Intégration avec DBT

Le backend partage la même base PostgreSQL que DBT:
- Tables source: `hirewire.*`
- L'API écrit directement dans PostgreSQL
- DBT lit depuis PostgreSQL et transforme vers DuckDB
- Lancer `dbt run` après modifications pour mettre à jour les marts

## Prochaines étapes

- [ ] Authentication avec JWT
- [ ] WebSockets pour notifications temps réel
- [ ] Upload de fichiers (CV, lettres motivation)
- [ ] Calendrier intégré pour interviews
- [ ] Notifications email
- [ ] Export PDF des statistiques
- [ ] Tests end-to-end avec Playwright
- [ ] CI/CD avec GitHub Actions

## Troubleshooting

### L'API ne démarre pas
```bash
# Vérifier les logs
docker-compose logs api

# Vérifier que PostgreSQL est prêt
docker-compose exec postgres pg_isready

# Recreate le container
docker-compose up -d --force-recreate api
```

### Le frontend ne se connecte pas à l'API
- Vérifier `VITE_API_URL` dans `.env`
- Vérifier CORS dans `backend/app/core/config.py`
- Vérifier que l'API est accessible: `curl http://localhost:8000/health`

### Problèmes de hot reload
```bash
# Backend: vérifier le volume mount
docker-compose exec api ls -la /app/app

# Frontend: vérifier node_modules
docker-compose exec frontend ls -la /app/node_modules
```

## Best Practices appliquées

✅ **Backend**
- Multi-stage Docker builds (optimisation taille)
- Health checks
- Pydantic pour validation
- SQLAlchemy avec relationships
- Services séparés pour business logic
- Configuration centralisée
- Logging structuré
- Security headers

✅ **Frontend**
- TypeScript strict
- React Query pour state management
- Vite pour dev speed
- Nginx optimisé (gzip, cache)
- SPA routing
- Environment-based config

✅ **DevOps**
- Docker Compose pour orchestration
- Développement vs Production séparés
- Health checks sur tous les services
- Volumes nommés pour persistance
- Networks isolés
- Restart policies

✅ **Sécurité**
- Non-root users dans containers
- Secret management avec .env
- CORS configuré
- Security headers (nginx)
- Input validation (Pydantic)
- SQL injection protection (SQLAlchemy)
