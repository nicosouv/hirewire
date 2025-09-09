# HireWire - Interview Analytics Platform

Un système d'analyse des entretiens d'embauche utilisant PostgreSQL, DBT, DuckDB et Metabase.

## Architecture

- **PostgreSQL** : Base de données principale pour stocker les données brutes
- **DBT** : Transformations des données et modélisation
- **DuckDB** : Base de données analytique pour les requêtes rapides
- **Metabase** : Interface de visualisation et dashboards

## Structure du projet

```
hirewire/
├── docker-compose.yml           # Orchestration des services
├── sql/
│   └── init/
│       └── 01_init_schema.sql  # Schema initial PostgreSQL
├── dbt_project/
│   ├── dbt_project.yml         # Configuration DBT
│   ├── packages.yml            # Dépendances DBT
│   └── models/
│       ├── staging/            # Modèles de staging
│       └── marts/              # Modèles analytiques
└── profiles/
    └── profiles.yml            # Configuration des connexions DBT
```

## Installation et démarrage

### Prérequis
- Docker et Docker Compose
- Git

### Démarrage des services

1. Cloner le projet et naviguer dans le dossier
```bash
cd hirewire
```

2. Démarrer tous les services
```bash
docker-compose up -d --build
```

3. Vérifier que tous les services sont actifs
```bash
docker-compose ps
```

4. Lancer le pipeline ETL complet
```bash
./scripts/etl_runner.sh
```

### Services disponibles

- **PostgreSQL** : `localhost:5432`
  - Base : `hirewire`
  - Utilisateur : `postgres`
  - Mot de passe : `password`

- **Metabase** : http://localhost:3000
  - Configuration initiale requise au premier démarrage

### Configuration DBT

1. Accéder au conteneur DBT
```bash
docker-compose exec dbt bash
```

2. Installer les dépendances DBT
```bash
dbt deps
```

3. Tester la connexion
```bash
dbt debug
```

4. Exécuter les modèles de staging
```bash
dbt run --models staging
```

5. Exécuter tous les modèles
```bash
dbt run
```

6. Lancer les tests
```bash
dbt test
```

## Structure des données

### Tables principales

1. **companies** : Informations sur les entreprises
2. **job_positions** : Postes proposés par les entreprises
3. **interview_processes** : Processus d'entretien pour chaque candidature
4. **interviews** : Entretiens individuels au sein d'un processus
5. **interview_outcomes** : Résultats finaux des processus

### Modèles DBT

#### Staging
- `stg_companies` : Nettoyage des données entreprises
- `stg_job_positions` : Nettoyage des données postes
- `stg_interview_processes` : Nettoyage des données processus
- `stg_interviews` : Nettoyage des données entretiens
- `stg_interview_outcomes` : Nettoyage des données résultats

#### Marts
- `mart_interview_summary` : Vue d'ensemble des processus d'entretien
- `mart_monthly_stats` : Statistiques mensuelles agrégées

## Utilisation

### Ajout de données

Connectez-vous à PostgreSQL et insérez vos données dans les tables du schema `hirewire`.

Exemple d'ajout d'une entreprise :
```sql
INSERT INTO hirewire.companies (name, industry, size, location)
VALUES ('TechCorp', 'Technology', '100-500', 'Paris, France');
```

### Exécution des transformations

Après ajout de nouvelles données :
```bash
docker-compose exec dbt dbt run
```

### Configuration Metabase

1. Accéder à http://localhost:3000
2. Configurer la connexion à PostgreSQL :
   - Host : `postgres`
   - Port : `5432`
   - Database : `hirewire`
   - Username : `postgres`
   - Password : `password`

## Arrêt des services

```bash
docker-compose down
```

Pour supprimer aussi les volumes (données) :
```bash
docker-compose down -v
```

## Développement

### Ajout de nouveaux modèles DBT

1. Créer le fichier SQL dans `dbt_project/models/`
2. Tester le modèle : `dbt run --models nom_du_modele`
3. Ajouter des tests dans un fichier YAML correspondant

### Extension du schéma

1. Modifier `sql/init/01_init_schema.sql`
2. Recréer les conteneurs : `docker-compose down -v && docker-compose up -d`