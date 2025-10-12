# Quick Start - Déploiement HireWire sur AWS

Guide rapide pour déployer HireWire sur AWS en 30 minutes.

## 🚀 Démarrage Rapide (3 étapes)

### 1️⃣ Prérequis (5 min)

```bash
# Installer les outils nécessaires
brew install terraform awscli

# Configurer AWS
aws configure
```

### 2️⃣ Configuration (5 min)

```bash
cd terraform/aws

# Copier et éditer la configuration
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Modifier owner_email et db_master_password

# Voir l'estimation des coûts
./scripts/cost-estimate.sh
```

### 3️⃣ Déploiement (20 min)

```bash
# Lancer le déploiement automatique
./scripts/deploy.sh

# ⏳ Attendre ~15-20 minutes
# ✅ C'est prêt !
```

## 💰 Coûts

**Estimation mensuelle : $100-150**

| Service | Coût |
|---------|------|
| Base de données (Aurora) | $50 |
| API + Airflow (ECS) | $68 |
| Frontend (S3 + CloudFront) | $8 |
| Réseau + Stockage | $20 |

## 📊 Résultat du Déploiement

Après le déploiement, vous aurez :

✅ **Frontend** : Application React sur CloudFront (CDN global)
✅ **API Backend** : FastAPI sur ECS Fargate (auto-scaling)
✅ **Base de données** : PostgreSQL Aurora Serverless v2
✅ **Orchestration** : Apache Airflow 3.x sur ECS
✅ **Analytics** : DBT + DuckDB sur ECS
✅ **Monitoring** : CloudWatch dashboards + alertes coûts
✅ **Sécurité** : VPC privé, chiffrement, IAM roles

## 🎯 Accès aux Services

```bash
# Récupérer les URLs
terraform output

# API Endpoint
API_URL=$(terraform output -raw api_endpoint)
echo "API: https://${API_URL}"

# Frontend URL
FRONTEND_URL=$(terraform output -raw frontend_cloudfront_url)
echo "Frontend: https://${FRONTEND_URL}"
```

## 🔍 Vérification

```bash
# Test API
curl https://$(terraform output -raw api_endpoint)/health

# Test Frontend
curl -I https://$(terraform output -raw frontend_cloudfront_url)
```

## 📖 Documentation Complète

- **[README.md](README.md)** : Architecture et détails des coûts
- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** : Guide complet de déploiement
- **Modules Terraform** : `modules/*/README.md`

## 🆘 Besoin d'Aide ?

**Problème fréquent : "Error creating RDS Cluster"**

→ Vérifiez que votre mot de passe fait au moins 16 caractères

**Problème : "Budget trop élevé"**

→ Voir les optimisations dans [README.md](README.md#-optimisation-des-coûts)

**Question : "Comment détruire l'infrastructure ?"**

→ `terraform destroy` (voir [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#-rollback--destruction))

## 🎉 Prochaines Étapes

1. **Construire et pousser les images Docker** → Voir [DEPLOYMENT_GUIDE.md Phase 4](DEPLOYMENT_GUIDE.md#phase-4-configuration-post-déploiement-️)
2. **Initialiser la base de données** → Exécuter les migrations SQL
3. **Déployer le frontend** → `aws s3 sync dist/ s3://bucket/`
4. **Configurer DNS** (optionnel) → Route53 + ACM SSL

## 💡 Conseils

- **Premier déploiement** : Utilisez les valeurs par défaut
- **Production** : Activez les Savings Plans après 1 mois pour -21% de réduction
- **Budget serré** : Voir les optimisations dans le README (~$90/mois possible)
- **Monitoring** : Configurez CloudWatch Alarms dès le premier jour

---

**Durée totale : ~30 minutes**

**Coût estimé : $100-150/mois**

**Support : Voir [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) pour troubleshooting**
