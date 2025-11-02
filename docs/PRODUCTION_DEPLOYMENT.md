# Production Deployment Guide

Ce guide explique comment déployer HireWire en production en utilisant les images Docker pré-construites depuis GitHub Container Registry (GHCR).

## 🚀 Quick Start

### Prérequis

- Docker et Docker Compose installés
- Accès aux images GHCR (publiques ou avec authentification)
- Fichier `.env` configuré avec vos variables d'environnement

### Démarrage Rapide

```bash
# 1. Configurer les variables d'environnement
cp backend/.env.example backend/.env
# Éditer backend/.env avec vos valeurs de production

# 2. Démarrer les services en production
docker-compose -f docker-compose.prod.yml up -d

# 3. Vérifier que tout fonctionne
docker-compose -f docker-compose.prod.yml ps
```

## 📦 Images Utilisées

Le fichier `docker-compose.prod.yml` utilise les images pré-construites suivantes :

| Service | Image GHCR | Version actuelle |
|---------|-----------|------------------|
| Backend | `ghcr.io/nicosouv/hirewire-backend` | 0.4.7 |
| Frontend | `ghcr.io/nicosouv/hirewire-frontend` | 0.4.6 |
| Airflow | `ghcr.io/nicosouv/hirewire-airflow` | latest |
| DBT | `ghcr.io/nicosouv/hirewire-dbt` | latest |

### Télécharger les Images

```bash
# Backend (multi-architecture: amd64 + arm64)
docker pull ghcr.io/nicosouv/hirewire-backend:0.4.7

# Frontend (amd64 uniquement)
docker pull --platform linux/amd64 ghcr.io/nicosouv/hirewire-frontend:0.4.6
```

## ⚙️  Configuration

### Variables d'Environnement Requises

Dans `backend/.env` :

```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password_here
POSTGRES_DB=hirewire

# Backend API
SECRET_KEY=your_secret_key_here_min_32_chars
ACCESS_TOKEN_EXPIRE_MINUTES=30

# SMTP (pour les exports)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_FROM=noreply@hirewire.com

# Backend API URL (for Airflow)
BACKEND_API_URL=http://api:8000
```

### Générer une SECRET_KEY

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

## 🔒 Sécurité

### Recommandations de Production

1. **Mots de passe forts** : Utilisez des mots de passe complexes pour PostgreSQL
2. **SECRET_KEY unique** : Ne réutilisez jamais la clé de développement
3. **HTTPS/SSL** : Configurez Nginx avec SSL (Let's Encrypt recommandé)
4. **Firewall** : N'exposez que les ports nécessaires
5. **Backups** : Configurez des sauvegardes régulières de PostgreSQL

### Configurer SSL avec Let's Encrypt

```bash
# Installer certbot
sudo apt-get install certbot python3-certbot-nginx

# Obtenir un certificat SSL
sudo certbot --nginx -d votre-domaine.com

# Redémarrer Nginx
docker-compose -f docker-compose.prod.yml restart nginx
```

## 📊 Monitoring et Logs

### Voir les logs

```bash
# Tous les services
docker-compose -f docker-compose.prod.yml logs -f

# Service spécifique
docker-compose -f docker-compose.prod.yml logs -f api
docker-compose -f docker-compose.prod.yml logs -f frontend

# Dernières 100 lignes
docker-compose -f docker-compose.prod.yml logs --tail=100 api
```

### Vérifier la santé des services

```bash
# Status de tous les services
docker-compose -f docker-compose.prod.yml ps

# Vérifier le backend health check
curl http://localhost:8000/health

# Vérifier le frontend
curl http://localhost:80
```

## 🔄 Mise à Jour

### Mettre à jour vers une nouvelle version

```bash
# 1. Télécharger les nouvelles images
docker pull ghcr.io/nicosouv/hirewire-backend:0.4.8
docker pull ghcr.io/nicosouv/hirewire-frontend:0.4.7

# 2. Modifier docker-compose.prod.yml avec les nouvelles versions
# image: ghcr.io/nicosouv/hirewire-backend:0.4.8

# 3. Redémarrer les services
docker-compose -f docker-compose.prod.yml up -d

# 4. Vérifier que tout fonctionne
docker-compose -f docker-compose.prod.yml ps
```

### Rollback vers une version précédente

```bash
# 1. Modifier docker-compose.prod.yml avec l'ancienne version
# image: ghcr.io/nicosouv/hirewire-backend:0.4.7

# 2. Redémarrer
docker-compose -f docker-compose.prod.yml up -d
```

## 🔧 Maintenance

### Nettoyer les anciennes images

```bash
# Supprimer les images inutilisées
docker image prune -a

# Nettoyer complètement le système Docker
docker system prune -a --volumes
```

### Backup de la base de données

```bash
# Backup PostgreSQL
docker exec hirewire_postgres_prod pg_dump -U postgres hirewire > backup_$(date +%Y%m%d).sql

# Restore
cat backup_20250102.sql | docker exec -i hirewire_postgres_prod psql -U postgres -d hirewire
```

## 🚨 Troubleshooting

### Service ne démarre pas

```bash
# Vérifier les logs
docker-compose -f docker-compose.prod.yml logs api

# Vérifier la configuration
docker-compose -f docker-compose.prod.yml config

# Recréer les containers
docker-compose -f docker-compose.prod.yml up -d --force-recreate
```

### Problèmes de connexion database

```bash
# Vérifier que PostgreSQL est accessible
docker exec hirewire_postgres_prod psql -U postgres -c "SELECT 1"

# Vérifier les variables d'environnement
docker inspect hirewire_api_prod | grep -A 10 Env
```

### Images ARM64 non disponibles

Si vous êtes sur Apple Silicon (M1/M2/M3) et que l'image frontend ne se télécharge pas :

```bash
# Utiliser explicitement la plateforme amd64 (déjà configuré dans docker-compose.prod.yml)
docker pull --platform linux/amd64 ghcr.io/nicosouv/hirewire-frontend:0.4.6
```

Le frontend est uniquement disponible en amd64 en raison d'un crash QEMU lors du build ARM64.

## 📈 Performance

### Optimisations Recommandées

1. **Augmenter les workers uvicorn** : Modifier dans l'image backend ou via env var
2. **Configurer PostgreSQL** : Tuner les paramètres PostgreSQL pour production
3. **Redis caching** : Activer le cache Redis pour les requêtes fréquentes
4. **CDN** : Utiliser un CDN pour servir le frontend
5. **Load balancing** : Configurer un load balancer pour scaling horizontal

## 🌐 Déploiement Cloud

### AWS ECS / Fargate

Les images GHCR peuvent être utilisées directement dans AWS ECS :

```bash
# Pull depuis GHCR vers ECR
aws ecr get-login-password | docker login --username AWS --password-stdin <account-id>.dkr.ecr.region.amazonaws.com
docker pull ghcr.io/nicosouv/hirewire-backend:0.4.7
docker tag ghcr.io/nicosouv/hirewire-backend:0.4.7 <account-id>.dkr.ecr.region.amazonaws.com/hirewire-backend:0.4.7
docker push <account-id>.dkr.ecr.region.amazonaws.com/hirewire-backend:0.4.7
```

### Google Cloud Run

```bash
gcloud run deploy hirewire-backend \
  --image ghcr.io/nicosouv/hirewire-backend:0.4.7 \
  --platform managed \
  --region europe-west1
```

### Azure Container Instances

```bash
az container create \
  --resource-group hirewire-rg \
  --name hirewire-backend \
  --image ghcr.io/nicosouv/hirewire-backend:0.4.7 \
  --ports 8000
```

## 📞 Support

Pour toute question ou problème :

1. Consulter la [documentation CI/CD](docs/CICD_GUIDE.md)
2. Vérifier les [issues GitHub](https://github.com/nicosouv/hirewire/issues)
3. Créer une nouvelle issue si nécessaire

## 🔗 Liens Utiles

- **GitHub Repository** : https://github.com/nicosouv/hirewire
- **GitHub Packages** : https://github.com/nicosouv?tab=packages
- **GitHub Releases** : https://github.com/nicosouv/hirewire/releases
- **CI/CD Workflows** : https://github.com/nicosouv/hirewire/actions
