# Airflow Setup Guide

## 🚀 Démarrage rapide

```bash
# Démarrer Airflow
docker-compose --profile airflow up -d

# Récupérer le mot de passe admin
./scripts/airflow/get_admin_password.sh
```

## 🔐 Authentification

Airflow 3.x utilise le **Simple Auth Manager** qui génère automatiquement un mot de passe unique à chaque démarrage du webserver.

### Récupérer les credentials

```bash
./scripts/airflow/get_admin_password.sh
```

**Sortie :**
```
═══════════════════════════════════════
👤 Username: admin
🔑 Password: gVe8DcTKhcVbtu2A
🌐 URL: http://localhost:8080
═══════════════════════════════════════
```

### ⚠️ Important

- Le mot de passe change à chaque rebuild/restart du container `airflow-webserver`
- Toujours exécuter le script `get_admin_password.sh` après un rebuild
- Le mot de passe est visible dans les logs du webserver

## 📋 DAGs

### DAGs disponibles

1. **daily_etl_pipeline** - Pipeline ETL complet (2 AM tous les jours)
   - Exécute les modèles DBT (staging → intermediate → marts)
   - Génère la documentation DBT
   - Vérifie la base DuckDB

2. **hourly_status_sync** - Sync horaire (9 AM - 7 PM en semaine)
   - Rafraîchit les applications actives
   - Met à jour les résumés d'entretiens
   - Vérifie la fraîcheur des données

3. **update_past_interviews** - Mise à jour automatique (toutes les 6h)
   - Met à jour les interviews passées de 'scheduled' à 'completed'
   - Appelle l'endpoint API `/api/v1/airflow/tasks/update-past-interviews`
   - Authentification via utilisateur système Airflow

### Forcer la découverte des DAGs

Si les DAGs n'apparaissent pas après un rebuild :

```bash
docker exec hirewire_airflow_scheduler airflow dags reserialize
```

### Dépausser les DAGs

```bash
docker exec hirewire_airflow_postgres psql -U airflow -d airflow -c \
  "UPDATE dag SET is_paused = false WHERE dag_id IN ('daily_etl_pipeline', 'hourly_status_sync', 'update_past_interviews');"
```

## 🔧 Configuration

### Variables Airflow requises

Configurées automatiquement au démarrage :
- `HIREWIRE_API_URL` : `http://api:8000`
- `HIREWIRE_API_TOKEN` : JWT token pour l'utilisateur système Airflow (expire après 1 an)
- `POSTGRES_USER` : `postgres`
- `POSTGRES_PASSWORD` : `password`

### Variables d'environnement critiques

Pour que les DAGs s'exécutent correctement, les services Airflow doivent avoir :
- `AIRFLOW__CORE__EXECUTION_API_SERVER_URL` : URL de l'API d'exécution des tâches
- `AIRFLOW__API_AUTH__JWT_SECRET` : Secret partagé pour l'authentification JWT

Ces variables sont déjà configurées dans `docker-compose.yml`.

### Utilisateur système API

Un utilisateur dédié existe pour les appels API depuis Airflow :
- Email : `airflow@hirewire.system`
- Privilège : `is_airflow_admin = true`
- Utilisé par les DAGs pour appeler les endpoints `/api/v1/airflow/*`

## 🐛 Troubleshooting

### Les DAGs n'apparaissent pas

```bash
# 1. Vérifier les erreurs d'import
docker exec hirewire_airflow_scheduler airflow dags list-import-errors

# 2. Forcer la resérialisation
docker exec hirewire_airflow_scheduler airflow dags reserialize

# 3. Vérifier que les DAGs sont importables
docker exec hirewire_airflow_scheduler bash -c "cd /opt/airflow/dags && python3 -c 'from daily_etl_pipeline import dag; print(dag.dag_id)'"
```

### Mot de passe oublié/perdu

```bash
./scripts/airflow/get_admin_password.sh
```

### Scheduler en boucle de redémarrage

Vérifier les logs :
```bash
docker logs hirewire_airflow_scheduler --tail 50
```

Causes communes :
- Erreur d'import dans les DAGs
- Problème de connexion à la base de données
- Email notifications (désactivé via `AIRFLOW__EMAIL__EMAIL_BACKEND`)

## 📚 Références

- [Airflow 3.x Documentation](https://airflow.apache.org/docs/apache-airflow/stable/)
- [Simple Auth Manager](https://airflow.apache.org/docs/apache-airflow/stable/security/api.html)
- [DAG Writing Best Practices](https://airflow.apache.org/docs/apache-airflow/stable/best-practices.html)
