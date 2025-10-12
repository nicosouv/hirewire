# Airflow Authentication System - Production Ready

## 🔐 Architecture de sécurité

Ce système implémente une authentification **production-ready** pour Apache Airflow 3, intégrée avec le backend FastAPI.

### Flow d'authentification

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ 1. Login via React App
       ↓
┌─────────────────┐
│  FastAPI /login │ → Returns JWT with is_airflow_admin claim
└────────┬────────┘
         │ 2. JWT Token stored in localStorage
         ↓
┌──────────────────┐
│ Nginx Proxy:8081 │ → Validates JWT via /api/v1/auth/me
└────────┬─────────┘
         │ 3. Check is_airflow_admin === true
         ↓
┌──────────────────┐
│ Airflow UI:8080  │ → Access granted ✅
└──────────────────┘
```

## 🛡️ Sécurité

### Principe de moindre privilège

- **Par défaut** : `is_airflow_admin = FALSE` pour tous les nouveaux utilisateurs
- **Accès explicite** : Seulement les users avec le flag `is_airflow_admin = TRUE` peuvent accéder
- **Validation centralisée** : Nginx valide CHAQUE requête via le backend FastAPI
- **Cache intelligent** : Les validations réussies sont mises en cache pendant 1 minute pour réduire la charge

### Protection multi-couches

1. **Layer 1 - Nginx** : Bloque les requêtes sans JWT valide
2. **Layer 2 - FastAPI** : Vérifie la signature JWT et la validité du token
3. **Layer 3 - Database** : Check `is_airflow_admin = TRUE` dans PostgreSQL
4. **Layer 4 - Airflow** : Application elle-même (defense in depth)

## 📋 Utilisation

### 1. Démarrer les services

```bash
# Démarrer la stack complète
docker-compose up -d api frontend

# Démarrer Airflow avec le proxy sécurisé
make airflow-init      # Première fois seulement
make airflow-start     # Démarre tous les services Airflow + Nginx
```

### 2. Se connecter à Airflow

```bash
# 1. Ouvrir l'app React
open http://localhost:5173

# 2. Se connecter avec vos credentials
Email: admin@hirewire.com
Password: <votre mot de passe>

# 3. Accéder à Airflow via le proxy sécurisé
open http://localhost:8081

# ✅ Si is_airflow_admin = TRUE → Access granted
# ❌ Si is_airflow_admin = FALSE → 403 Forbidden
```

### 3. Gérer les accès Airflow

```bash
# Donner l'accès Airflow à un utilisateur
docker-compose exec postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.users
SET is_airflow_admin = TRUE
WHERE email = 'user@example.com';
"

# Révoquer l'accès
docker-compose exec postgres psql -U postgres -d hirewire -c "
UPDATE hirewire.users
SET is_airflow_admin = FALSE
WHERE email = 'user@example.com';
"

# Lister les admins Airflow
docker-compose exec postgres psql -U postgres -d hirewire -c "
SELECT id, email, first_name, last_name, is_airflow_admin
FROM hirewire.users
WHERE is_airflow_admin = TRUE;
"
```

## 🔧 Configuration

### Variables d'environnement

```bash
# .env
AIRFLOW_USERNAME=admin
AIRFLOW_PASSWORD=admin
AIRFLOW_POSTGRES_PASSWORD=airflow
AIRFLOW_FERNET_KEY=46BKJoQYlPPOexq0OhDZnIlNepKFf87WFwLbfzqDDho=
```

### Ports

- **8080** : Airflow UI (non exposé, accès via proxy seulement)
- **8081** : Nginx Proxy sécurisé (point d'entrée public pour Airflow)
- **5173** : React App (pour login)
- **8000** : FastAPI Backend (validation JWT)

## 🚨 Troubleshooting

### Problème : 403 Forbidden

**Cause** : L'utilisateur n'a pas `is_airflow_admin = TRUE`

**Solution** :
```sql
UPDATE hirewire.users SET is_airflow_admin = TRUE WHERE email = 'your@email.com';
```

### Problème : 401 Unauthorized

**Cause** : JWT token invalide ou expiré

**Solution** :
1. Logout de l'app React
2. Login à nouveau pour obtenir un nouveau JWT
3. Réessayer d'accéder à Airflow

### Problème : Redirect loop

**Cause** : Le token n'est pas envoyé correctement à Nginx

**Solution** :
1. Vérifier que le JWT est dans localStorage
2. S'assurer que le frontend envoie le token dans l'Authorization header
3. Checker les logs Nginx : `docker-compose logs nginx-airflow`

### Débugger l'authentification

```bash
# Voir les logs Nginx
docker-compose logs -f nginx-airflow

# Tester la validation JWT manuellement
TOKEN="your-jwt-token"
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/v1/auth/me

# Vérifier le status is_airflow_admin dans la DB
docker-compose exec postgres psql -U postgres -d hirewire -c "
SELECT email, is_airflow_admin FROM hirewire.users WHERE email = 'your@email.com';
"
```

## 📊 Monitoring

### Healthchecks

```bash
# Nginx proxy
curl http://localhost:8081/health

# FastAPI backend
curl http://localhost:8000/health

# Airflow (via proxy)
curl http://localhost:8081/api/v2/monitor/health
```

### Métriques

- **Cache hit rate** : Nginx auth cache (`/tmp/nginx_auth_cache`)
- **Auth failures** : Logs Nginx filtered by 401/403
- **Active sessions** : Check JWT tokens in localStorage

## 🎯 Best Practices

1. **Ne jamais exposer le port 8080** (Airflow direct) en production
2. **Toujours accéder via le port 8081** (Nginx proxy sécurisé)
3. **Auditer régulièrement** la liste des `is_airflow_admin = TRUE`
4. **Utiliser HTTPS** en production avec certificats SSL/TLS
5. **Configurer des timeouts JWT** appropriés (défaut: 30 jours → réduire à 1 jour en prod)
6. **Monitorer les tentatives d'accès** échouées (401/403)

## 🔄 Migration depuis l'ancienne approche

Si vous aviez configuré un Custom Auth Manager qui ne fonctionne pas :

1. ✅ **Conserver** : `is_airflow_admin` field dans la DB
2. ✅ **Conserver** : JWT claims avec `is_airflow_admin`
3. ❌ **Supprimer** : Custom Auth Manager Python (non nécessaire avec Nginx)
4. ✅ **Utiliser** : Nginx reverse proxy pour validation (plus simple + plus performant)

## 📚 Références

- [Airflow 3.x Documentation](https://airflow.apache.org/docs/apache-airflow/stable/)
- [Nginx auth_request Module](http://nginx.org/en/docs/http/ngx_http_auth_request_module.html)
- [JWT Best Practices](https://datatracker.ietf.org/doc/html/rfc8725)
