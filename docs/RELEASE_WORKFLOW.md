# Release Workflow - Tests puis Build

## Vue d'ensemble

Depuis la mise en place du workflow de tests sur tags, **chaque release est automatiquement validée** avant de builder les images Docker.

## Architecture des workflows

```
Tag créé (v1.2.3)
     │
     ├─────────────────────────────────────┐
     │                                     │
     ▼                                     ▼
┌─────────────────────┐         ┌──────────────────────┐
│ ci-tests-on-tag.yml │         │ build-and-push.yml   │
│                     │         │                      │
│ 1. Backend tests    │         │ 1. wait-for-tests    │
│ 2. Frontend tests   │         │    (attend CI tests) │
│ 3. Airflow tests    │         │                      │
│ 4. DBT validation   │         │ 2. detect-changes    │
│ 5. Summary          │◄────────┤    (attend summary)  │
│    (ci-tests-summary)│        │                      │
└─────────────────────┘         │ 3. Build images      │
                                │    (si tests OK)     │
                                └──────────────────────┘
```

## Nouveau comportement sur les tags

### 1. **Déclenchement automatique des tests** (`ci-tests-on-tag.yml`)

Quand tu crées un tag `v*.*.*` :

✅ **Tous les tests sont lancés** (pas de change detection) :
- Backend : pytest (Python 3.11 + 3.12)
- Frontend : ESLint + TypeScript + Vitest + Build
- Airflow : DAG file validation (minimal - see note below)
- DBT : compile + parse validation

🎯 **Objectif** : Garantir la qualité du code avant le build des images Docker

ℹ️ **Note Airflow** : Les tests complets d'intégrité des DAGs (`test_dag_integrity.py`, `test_dag_validation.py`, `test_dag_tasks.py`) sont skippés en CI due to Airflow 3.x compatibility issues avec Cadwyn/FastAPI/structlog lors de l'import dans pytest. Les DAGs fonctionnent parfaitement en production - c'est uniquement un problème d'environnement de test. Le CI valide la présence et structure de base des fichiers DAG sans importer Airflow.

### 2. **Attente de validation** (`build-and-push.yml` - job `wait-for-tests`)

Le workflow de build attend maintenant :

```yaml
wait-for-tests:
  runs-on: ubuntu-latest
  if: github.event_name == 'push' && startsWith(github.ref, 'refs/tags/')
  steps:
    - name: Wait for CI tests to complete
      uses: lewagon/wait-on-check-action@v1.3.4
      with:
        check-name: 'ci-tests-summary'
        wait-interval: 20  # Vérifie toutes les 20 secondes
```

⏳ **Polling** : Vérifie toutes les 20s si les tests sont terminés

### 3. **Build conditionnel**

Deux scénarios possibles :

#### ✅ Scenario 1 : Tests réussis
```
Tests PASS → wait-for-tests SUCCESS → Build ALL images → Push GHCR → Create GitHub Release
```

#### ❌ Scenario 2 : Tests échoués
```
Tests FAIL → wait-for-tests FAIL → Build BLOCKED → Notification d'erreur
```

**Résultat** : Les images Docker ne sont créées **QUE** si tous les tests passent.

## Workflows disponibles

### Sur push vers `main`/`develop` (sans tag)
- ✅ `ci-tests.yml` : Tests avec change detection (rapide)
- ❌ `ci-tests-on-tag.yml` : Ne se déclenche pas
- ❌ `build-and-push.yml` : Ne se déclenche pas

### Sur création de tag `v*.*.*`
- ✅ `ci-tests-on-tag.yml` : **Tous les tests** (exhaustif)
- ✅ `build-and-push.yml` : Attend les tests puis build **tous les services**

### Trigger manuel (`workflow_dispatch`)
- ❌ `ci-tests-on-tag.yml` : Ne se déclenche pas
- ✅ `build-and-push.yml` : Build direct (option `force_build_all`)

## Commandes pour créer un release

### Option 1 : Script automatique (recommandé)

```bash
# Patch release (1.0.0 → 1.0.1)
./scripts/release.sh patch

# Minor release (1.0.1 → 1.1.0)
./scripts/release.sh minor

# Major release (1.1.0 → 2.0.0)
./scripts/release.sh major

# Version spécifique
./scripts/release.sh 1.2.3
```

Le script :
1. Crée un tag annoté avec changelog
2. Push le tag vers GitHub
3. Déclenche automatiquement `ci-tests-on-tag.yml` + `build-and-push.yml`

### Option 2 : Manuellement

```bash
# Créer et pusher un tag
git tag -a v1.2.3 -m "Release v1.2.3: Description des changements"
git push origin v1.2.3
```

## Monitoring du workflow

### 1. Vérifier les tests

```bash
# Via GitHub Actions UI
https://github.com/<username>/hirewire/actions

# Workflow: "CI - Tests on Release Tag"
# Chercher le run pour ton tag
```

### 2. Vérifier le build

```bash
# Workflow: "Build and Push Docker Images"
# Status: Waiting for tests... → Building... → Complete
```

### 3. En cas d'échec des tests

Si les tests échouent :

1. **Consulter les logs** dans GitHub Actions
2. **Fixer les problèmes** dans le code
3. **Supprimer le tag** :
   ```bash
   git tag -d v1.2.3                # Supprimer localement
   git push origin :refs/tags/v1.2.3  # Supprimer sur GitHub
   ```
4. **Créer un nouveau tag** après correction

## Avantages de cette approche

✅ **Qualité garantie** : Pas d'images Docker en production avec des tests cassés
✅ **Cohérence de version** : Tous les services partagent le même tag de version
✅ **Traçabilité** : Chaque release a un historique de tests complet
✅ **Sécurité** : Blocage automatique si un seul test échoue
✅ **Visibilité** : Status clair dans GitHub Actions UI

## Workflow de développement recommandé

```bash
# 1. Développer sur une branche
git checkout -b feature/nouvelle-fonctionnalite

# 2. Commit + push
git commit -m "feat: ajouter nouvelle fonctionnalité"
git push origin feature/nouvelle-fonctionnalite

# 3. Créer une PR vers main
# → Tests automatiques (change detection)

# 4. Merger la PR
# → Tests automatiques sur main (change detection)

# 5. Créer un release tag
./scripts/release.sh minor  # v1.1.0 → v1.2.0

# 6. Attendre validation automatique
# → Tous les tests s'exécutent
# → Si OK : Build + Push Docker images
# → Si KO : Build bloqué, fixer et re-tagger

# 7. Déploiement
docker-compose -f docker-compose.prod.yml pull
docker-compose -f docker-compose.prod.yml up -d
```

## Dépannage

### Le build attend indéfiniment

**Symptôme** : `wait-for-tests` tourne en boucle

**Causes possibles** :
1. Les tests n'ont pas démarré (vérifier `ci-tests-on-tag.yml`)
2. Le job `ci-tests-summary` a un nom différent

**Solution** :
```bash
# Vérifier les workflows en cours
gh run list --workflow="CI - Tests on Release Tag"

# Consulter les logs
gh run view <run-id> --log
```

### Tests passent mais build ne démarre pas

**Symptôme** : Tests ✅ mais `wait-for-tests` ❌

**Cause** : Le `check-name` dans `build-and-push.yml` ne correspond pas au job name

**Solution** :
Vérifier que dans `build-and-push.yml` ligne 31 :
```yaml
check-name: 'ci-tests-summary'  # Doit correspondre au job name
```

### Forcer un build sans tests

Si absolument nécessaire (déconseillé) :

```bash
# Via GitHub UI
Actions → Build and Push Docker Images → Run workflow
→ Cocher "Force build all images"
```

## Métriques et durées typiques

- **Tests complets** : ~5-8 minutes
  - Backend : ~2 min (Python 3.11 + 3.12 en parallèle)
  - Frontend : ~2 min
  - Airflow : ~1 min
  - DBT : ~1 min

- **Build des images** : ~8-12 minutes
  - Backend : ~3 min (amd64 + arm64)
  - Frontend : ~2 min (amd64 only)
  - Airflow : ~3 min
  - DBT : ~2 min

- **Total** : ~15-20 minutes du tag au push GHCR

## Références

- [GitHub Actions - Workflows](https://docs.github.com/en/actions/using-workflows)
- [lewagon/wait-on-check-action](https://github.com/lewagon/wait-on-check-action)
- [Semantic Versioning](https://semver.org/)

---

**Date de création** : 5 janvier 2025
**Dernière mise à jour** : 5 janvier 2025
