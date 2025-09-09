# Configuration Apache Superset pour HireWire

## 🎨 Apache Superset avec DuckDB

Apache Superset est une alternative moderne à Metabase avec un support natif pour DuckDB via SQLAlchemy.

### Avantages de Superset vs Metabase

✅ **Superset** :
- Support natif DuckDB via `duckdb-engine`
- Interface plus moderne et customisable
- Fonctionnalités avancées (filtres cross-dashboard, etc.)
- Open source avec communauté active
- SQL Lab intégré pour les requêtes ad-hoc

✅ **Metabase** :
- Setup plus simple
- Interface plus simple pour les non-techniques
- Moins de configuration requise

## 🚀 Démarrage de Superset

### 1. Lancer Superset avec le profil

```bash
# Démarrer Superset (+ Redis + PostgreSQL)
docker-compose --profile superset up -d superset

# Vérifier que les services sont prêts
docker-compose ps
```

### 2. Initialiser Superset

```bash
# Initialisation automatique (recommandé)
./scripts/main.sh setup superset

# Ou manuellement
docker-compose exec superset superset db upgrade
docker-compose exec superset superset fab create-admin \
    --username admin --password admin \
    --firstname Admin --lastname User \
    --email admin@hirewire.local
docker-compose exec superset superset init
```

### 3. Accès à Superset

- **URL** : http://localhost:8088
- **Username** : `admin`
- **Password** : `admin`

## 📊 Configuration DuckDB

### Connexion automatique

Le script d'initialisation crée automatiquement la connexion DuckDB :

- **Nom** : `HireWire DuckDB`
- **URI** : `duckdb:////app/duckdb-data/hirewire.duckdb`
- **SQL Lab** : ✅ Activé
- **Upload CSV** : ✅ Activé

### Connexion manuelle (si nécessaire)

1. **Settings → Database Connections → + Database**
2. **Sélectionner "DuckDB"**
3. **Configuration** :
   ```
   Host: /app/duckdb-data/hirewire.duckdb
   ```

## 🎯 Tables recommandées pour les dashboards

### ✨ Tables Marts (principales)

| Table | Description | Visualisations recommandées |
|-------|-------------|------------------------------|
| **`mart_interview_dashboard`** | 🎯 **Table principale** | Dashboard global, métriques KPI |
| **`mart_company_metrics`** | Métriques par entreprise | Comparaison entreprises, scatter plots |
| **`mart_monthly_trends`** | Évolution temporelle | Time series, tendances |
| `mart_interview_analytics` | Analytics détaillés | Analyses avancées |
| `mart_companies_summary` | Liste des entreprises | Tables de référence |

## 🎨 Exemples de dashboards Superset

### 📈 Dashboard Principal

**Métriques clés** :
```sql
-- Total candidatures
SELECT COUNT(*) as total_applications 
FROM mart_interview_dashboard;

-- Taux de succès
SELECT 
  SUM(is_success) * 100.0 / COUNT(*) as success_rate
FROM mart_interview_dashboard;

-- Durée moyenne des processus
SELECT AVG(process_duration_days) as avg_duration
FROM mart_interview_dashboard
WHERE process_duration_days IS NOT NULL;
```

**Graphiques** :
- 📊 **Big Numbers** : Total candidatures, taux de succès, durée moyenne
- 🥧 **Pie Chart** : Répartition par `status_category`
- 📅 **Time Series** : Evolution des candidatures par `application_date`
- 🏢 **Bar Chart** : Candidatures par `company_name`

### 🏢 Dashboard Entreprises

```sql
-- Top entreprises par taux de succès
SELECT 
  company_name,
  total_applications,
  success_rate_pct,
  avg_offer_salary
FROM mart_company_metrics
ORDER BY success_rate_pct DESC;
```

**Visualisations** :
- 📊 **Table** : Ranking des entreprises
- 💰 **Scatter Plot** : `total_applications` vs `success_rate_pct`
- 🎯 **Heatmap** : `industry` vs métriques

### 📅 Dashboard Temporel

```sql
-- Évolution mensuelle
SELECT 
  month,
  applications_count,
  success_rate_pct,
  avg_process_duration
FROM mart_monthly_trends
ORDER BY month;
```

**Visualisations** :
- 📈 **Line Chart** : Évolution candidatures et taux de succès
- 📊 **Stacked Bar** : Sources de candidatures par mois
- 🌡️ **Area Chart** : Durée moyenne des processus

## 🛠️ Fonctionnalités avancées Superset

### SQL Lab
- Requêtes ad-hoc sur les données
- Export CSV/Excel
- Sauvegarde des requêtes

### Filtres Cross-Dashboard
- Filtres qui s'appliquent à plusieurs graphiques
- Interactions entre visualisations
- Drill-down capabilities

### Alertes et Rapports
- Alertes sur seuils (ex: taux de succès < 10%)
- Rapports automatiques par email
- Scheduling des dashboards

## 🔄 Mise à jour des données

```bash
# Mettre à jour les données dans DuckDB
./scripts/main.sh etl run

# Superset verra automatiquement les nouvelles données
# Optionnel: Refresh metadata des tables
# Settings → Database Connections → HireWire DuckDB → Sync columns from Source
```

## 🐳 Architecture Docker

```yaml
# Services pour Superset
services:
  redis:         # Cache et broker Celery
  superset:      # Interface web
  postgres:      # Metadata database (partagé avec Metabase)
  
# Volumes
volumes:
  superset_data: # Configuration et uploads Superset
  redis_data:    # Cache Redis
  ./data:        # DuckDB files (bind mount)
```

## 🆚 Superset vs Metabase - Comparaison

| Critère | Superset | Metabase |
|---------|----------|----------|
| **Setup** | ⭐⭐⭐ Moyen | ⭐⭐⭐⭐⭐ Simple |
| **Interface** | ⭐⭐⭐⭐⭐ Moderne | ⭐⭐⭐⭐ Clean |
| **Customisation** | ⭐⭐⭐⭐⭐ Très flexible | ⭐⭐⭐ Limitée |
| **Fonctionnalités** | ⭐⭐⭐⭐⭐ Avancées | ⭐⭐⭐⭐ Suffisantes |
| **Performance** | ⭐⭐⭐⭐ Bonne | ⭐⭐⭐⭐ Bonne |
| **SQL Support** | ⭐⭐⭐⭐⭐ SQL Lab | ⭐⭐⭐⭐ Bon |

## 🎯 Recommandation

- **Utilisateurs techniques** → Superset (plus de contrôle)
- **Utilisateurs business** → Metabase (plus simple)
- **Analyses avancées** → Superset (SQL Lab, filtres cross-dashboard)
- **Dashboards simples** → Metabase (setup plus rapide)