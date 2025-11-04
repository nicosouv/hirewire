# Gamification Audit System

Système automatisé de vérification et correction de l'intégrité des données de gamification.

## Vue d'ensemble

Le système de gamification audit assure que les points, niveaux, achievements et compteurs de chaque utilisateur restent cohérents avec les données réelles. Il fonctionne en deux parties :

1. **Vérification nocturne automatique** : Détecte les incohérences chaque nuit à 3h
2. **Recalcul automatique ou manuel** : Corrige les données incohérentes

## Architecture

```
┌─────────────────────────────────────┐
│  Nightly Audit DAG (3h du matin)   │
│                                     │
│  1. Verify gamification             │
│  2. Detect errors                   │
│  3. Trigger recalculations          │
│  4. Send email notification         │
└─────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────┐
│  Recalculate User Gamification DAG  │
│  (triggered per user)               │
│                                     │
│  1. Validate configuration          │
│  2. Verify user exists              │
│  3. Recalculate data                │
│  4. Verify success                  │
│  5. Send notification               │
└─────────────────────────────────────┘
```

## API Endpoints

### 1. Vérification de l'intégrité

```bash
POST /api/v1/airflow/tasks/verify-gamification
Authorization: Bearer <airflow_admin_token>
```

**Vérifications effectuées** :
- ✓ Compteurs incohérents (applications_count, interviews_count, offers_count)
- ✓ Achievements manquants (devrait être débloqué mais ne l'est pas)
- ✓ Points incorrects (total_points ≠ somme des achievements)
- ✓ Niveau incorrect (level ≠ floor(sqrt(points/100)) + 1)

**Exemple de réponse** :
```json
{
  "message": "Gamification verification complete: 2 errors found across 1 users",
  "total_users_checked": 4,
  "users_with_errors_count": 1,
  "total_errors_found": 2,
  "error_summary": {
    "counter_errors": 1,
    "missing_achievements": 1,
    "point_errors": 0,
    "level_errors": 0
  },
  "users_with_errors": [
    {
      "user_id": 1,
      "email": "admin@hirewire.com",
      "error_types": ["counter_mismatch", "missing_achievements"]
    }
  ],
  "error_details": {
    "counter_errors": [...],
    "missing_achievements": [...],
    "point_errors": [],
    "level_errors": []
  },
  "users_to_fix": [1]
}
```

### 2. Recalcul pour un utilisateur

```bash
POST /api/v1/airflow/tasks/recalculate-gamification/{user_id}?strategy=incremental
Authorization: Bearer <airflow_admin_token>
```

**Paramètres** :
- `user_id` (path) : ID de l'utilisateur à recalculer
- `strategy` (query) : `incremental` ou `full_reset`

**Stratégies** :

| Stratégie | Description | Quand l'utiliser |
|-----------|-------------|------------------|
| `incremental` | Corrige uniquement les incohérences détectées | Erreurs mineures (compteurs, level) |
| `full_reset` | Supprime tout et recalcule from scratch | Erreurs graves (achievements manquants, points incorrects) |

**Exemple de réponse** :
```json
{
  "message": "Successfully recalculated gamification data for user 1",
  "user_id": 1,
  "user_email": "admin@hirewire.com",
  "strategy": "full_reset",
  "before": {
    "total_points": 20,
    "level": 1,
    "applications_count": 0,
    "interviews_count": 3,
    "offers_count": 0,
    "achievements_count": 1
  },
  "after": {
    "total_points": 405,
    "level": 3,
    "applications_count": 33,
    "interviews_count": 17,
    "offers_count": 0,
    "achievements_count": 6
  },
  "changes": [
    "Deleted 1 achievements",
    "Reset all stats to zero",
    "Recalculated counters: apps=33, interviews=17, offers=0",
    "Unlocked 6 achievements: first_app, app_10, app_25, first_interview, interview_5, interview_10",
    "Recalculated points: 405 XP from 6 achievements",
    "Updated level to 3"
  ],
  "changes_summary": {
    "points_change": 385,
    "level_change": 2,
    "achievements_change": 5
  }
}
```

## DAGs Airflow

### 1. Nightly Gamification Audit

**DAG ID** : `nightly_gamification_audit`

**Schedule** : Tous les jours à 3h du matin (Europe/Paris)

**Tags** : `gamification`, `audit`, `nightly`, `maintenance`

**Workflow** :
1. **verify_gamification** : Vérifie tous les utilisateurs
2. **check_fixes_needed** : Détermine si des corrections sont nécessaires
3. **trigger_recalculations** : Lance le recalcul pour chaque utilisateur avec erreurs
4. **send_notification** : Envoie un email récapitulatif
5. **success_no_errors** : Message de succès si aucune erreur

**Logs typiques** :
```
================================================================================
GAMIFICATION AUDIT RESULTS
================================================================================
Total users checked: 4
Users with errors: 1
Total errors found: 2

Error breakdown:
  - Counter errors: 1
  - Missing achievements: 1
  - Point errors: 0
  - Level errors: 0
================================================================================
```

### 2. Recalculate User Gamification

**DAG ID** : `recalculate_user_gamification`

**Schedule** : Manuel uniquement (trigger on-demand)

**Tags** : `gamification`, `recalculation`, `manual`, `maintenance`

**Usage manuel** :
```bash
# Recalcul incrémental
airflow dags trigger recalculate_user_gamification \
  --conf '{"user_id": 1, "strategy": "incremental"}'

# Recalcul complet (full reset)
airflow dags trigger recalculate_user_gamification \
  --conf '{"user_id": 1, "strategy": "full_reset"}'
```

**Workflow** :
1. **validate_config** : Valide la configuration (user_id requis)
2. **verify_user** : Vérifie que l'utilisateur existe
3. **recalculate** : Effectue le recalcul
4. **verify_after** : Vérifie qu'il n'y a plus d'erreurs
5. **send_notification** : Notifie le résultat

## Notifications par email

Les deux DAGs envoient des notifications par email :

**Nightly Audit** :
- Destinataire : `SMTP_USER` (défini dans .env)
- Sujet : "Gamification Audit Report - [date]"
- Contenu :
  - Nombre total d'erreurs détectées
  - Liste des utilisateurs corrigés
  - Liste des utilisateurs en échec (nécessitent intervention manuelle)
  - Détails des erreurs par type

**Recalculation** :
- Destinataire : `SMTP_USER` (défini dans .env)
- Sujet : "Gamification Recalculation Complete - User [user_id]"
- Contenu :
  - Résumé avant/après
  - Liste des changements effectués
  - Statut de vérification post-recalcul

## Configuration

### Variables d'environnement

Ajouter au `.env` :
```bash
# Airflow system user password (for API calls)
AIRFLOW_SYSTEM_PASSWORD=airflow_secure_password_2025

# SMTP configuration (pour les notifications)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### Créer l'utilisateur système Airflow

```sql
INSERT INTO hirewire.users (email, hashed_password, is_airflow_admin)
VALUES (
  'airflow@hirewire.system',
  '<hashed_password>',  -- Use bcrypt hash
  TRUE
);
```

## Tests manuels

### 1. Tester la vérification

```bash
# Obtenir un token admin
TOKEN=$(curl -s -X POST http://localhost:8000/api/v1/auth/login/json \
  -H "Content-Type: application/json" \
  -d '{"email": "admin@hirewire.com", "password": "admin"}' | \
  jq -r '.access_token')

# Lancer la vérification
curl -s -X POST http://localhost:8000/api/v1/airflow/tasks/verify-gamification \
  -H "Authorization: Bearer $TOKEN" | jq
```

### 2. Tester le recalcul

```bash
# Recalcul full_reset pour user 1
curl -s -X POST "http://localhost:8000/api/v1/airflow/tasks/recalculate-gamification/1?strategy=full_reset" \
  -H "Authorization: Bearer $TOKEN" | jq

# Vérifier qu'il n'y a plus d'erreurs
curl -s -X POST http://localhost:8000/api/v1/airflow/tasks/verify-gamification \
  -H "Authorization: Bearer $TOKEN" | jq '.total_errors_found'
```

### 3. Tester les DAGs Airflow

```bash
# Déclencher l'audit nocturne manuellement
docker exec hirewire_airflow_scheduler \
  airflow dags trigger nightly_gamification_audit

# Déclencher un recalcul manuel
docker exec hirewire_airflow_scheduler \
  airflow dags trigger recalculate_user_gamification \
  --conf '{"user_id": 1, "strategy": "incremental"}'

# Vérifier le statut
docker exec hirewire_airflow_scheduler \
  airflow dags list-runs -d nightly_gamification_audit
```

## Monitoring

### Vérifier l'intégrité manuellement

```sql
-- Vérifier les compteurs incohérents
SELECT
    u.id,
    u.email,
    us.applications_count as stored_apps,
    COUNT(DISTINCT ip.id) as actual_apps,
    us.interviews_count as stored_interviews,
    COUNT(DISTINCT i.id) as actual_interviews
FROM hirewire.users u
LEFT JOIN hirewire.user_stats us ON u.id = us.user_id
LEFT JOIN hirewire.interview_processes ip ON u.id = ip.user_id
LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
GROUP BY u.id, u.email, us.applications_count, us.interviews_count
HAVING
    us.applications_count != COUNT(DISTINCT ip.id) OR
    us.interviews_count != COUNT(DISTINCT i.id);

-- Vérifier les achievements manquants
SELECT
    u.id,
    u.email,
    us.interviews_count,
    a.code,
    a.name,
    (a.criteria->>'target')::INTEGER as required_count
FROM hirewire.users u
JOIN hirewire.user_stats us ON u.id = us.user_id
CROSS JOIN hirewire.achievements a
WHERE a.criteria->>'type' = 'count'
  AND a.criteria->>'metric' = 'interviews'
  AND (a.criteria->>'target')::INTEGER <= us.interviews_count
  AND a.id NOT IN (
    SELECT achievement_id FROM hirewire.user_achievements WHERE user_id = u.id
  );

-- Vérifier les points incorrects
SELECT
    u.id,
    u.email,
    us.total_points as stored_points,
    COALESCE(SUM(a.points), 0) as actual_points
FROM hirewire.users u
LEFT JOIN hirewire.user_stats us ON u.id = us.user_id
LEFT JOIN hirewire.user_achievements ua ON u.id = ua.user_id
LEFT JOIN hirewire.achievements a ON ua.achievement_id = a.id
GROUP BY u.id, u.email, us.total_points
HAVING us.total_points != COALESCE(SUM(a.points), 0);
```

### Logs Airflow

```bash
# Logs du scheduler
docker logs hirewire_airflow_scheduler --tail 100

# Logs du worker
docker logs hirewire_airflow_worker --tail 100

# Logs du DAG processor
docker logs hirewire_airflow_dag_processor --tail 100

# Logs d'une task spécifique
docker exec hirewire_airflow_scheduler \
  airflow tasks logs nightly_gamification_audit verify_gamification 2025-11-04
```

## Dépannage

### Problème : DAG ne se déclenche pas automatiquement

**Solution** :
1. Vérifier que le DAG est activé (unpause)
   ```bash
   docker exec hirewire_airflow_scheduler airflow dags unpause nightly_gamification_audit
   ```

2. Vérifier le schedule dans le DAG
   ```python
   schedule='0 3 * * *'  # 3h du matin tous les jours
   ```

### Problème : Erreur "Could not validate credentials"

**Solution** :
1. Vérifier que l'utilisateur airflow@hirewire.system existe
2. Vérifier que `is_airflow_admin = TRUE`
3. Vérifier le mot de passe dans `.env` (AIRFLOW_SYSTEM_PASSWORD)

### Problème : Module 'requests' non trouvé

**Solution** :
```bash
# Installer requests dans le container Airflow
docker exec hirewire_airflow_worker pip install requests
docker exec hirewire_airflow_scheduler pip install requests
```

### Problème : Recalcul ne corrige pas les erreurs

**Solution** :
1. Utiliser `full_reset` au lieu de `incremental`
2. Vérifier les logs de la tâche pour identifier l'erreur
3. Vérifier manuellement les données en base avec les requêtes SQL ci-dessus

## Métriques et alertes

### Métriques à surveiller

1. **Taux d'erreurs** : Nombre d'utilisateurs avec erreurs / Total utilisateurs
2. **Taux de succès des recalculs** : Recalculs réussis / Total recalculs
3. **Temps d'exécution** : Durée de l'audit nocturne
4. **Alertes** : Envoyer une alerte si > 10% des utilisateurs ont des erreurs

### Dashboards recommandés

Créer des dashboards Superset pour :
- Évolution du taux d'erreurs dans le temps
- Distribution des types d'erreurs
- Top 10 utilisateurs avec le plus d'erreurs
- Historique des recalculs (succès vs échecs)

## Maintenance

### Tâches hebdomadaires

- Vérifier les emails de notification pour identifier les patterns d'erreurs
- Vérifier les logs Airflow pour détecter les échecs répétés
- Analyser les erreurs récurrentes pour identifier des bugs potentiels

### Tâches mensuelles

- Analyser les métriques d'intégrité des données
- Optimiser les requêtes SQL si les vérifications sont lentes
- Mettre à jour la documentation si nécessaire

## Évolutions futures

- [ ] Support des streaks dans la vérification
- [ ] Auto-détection des achievements "special" (early_bird, night_owl, etc.)
- [ ] Notification Slack en plus des emails
- [ ] Dashboard temps réel de l'intégrité gamification
- [ ] Historique des corrections (audit trail)
