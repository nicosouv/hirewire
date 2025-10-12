# Guide de Déploiement HireWire sur AWS

## 🎯 Checklist Complète de Déploiement

### Phase 1: Préparation (Local) ✅

- [ ] Vérifier que l'application fonctionne en local avec Docker
- [ ] Créer un compte AWS (si pas déjà fait)
- [ ] Installer AWS CLI et Terraform
- [ ] Configurer les credentials AWS
- [ ] Générer un mot de passe fort pour la base de données
- [ ] Estimer les coûts mensuels

### Phase 2: Configuration Terraform 🔧

- [ ] Copier `terraform.tfvars.example` vers `terraform.tfvars`
- [ ] Remplir les variables:
  - `owner_email`: Votre email pour les alertes
  - `db_master_password`: Mot de passe fort (16+ caractères)
  - `monthly_budget_limit`: Budget mensuel (défaut: $150)
  - `domain_name`: (optionnel) Votre domaine custom
- [ ] Exécuter `./scripts/cost-estimate.sh` pour voir les coûts
- [ ] Ajuster les configurations si besoin

### Phase 3: Déploiement de l'Infrastructure 🚀

```bash
cd terraform/aws

# Option A: Déploiement automatique (recommandé)
./scripts/deploy.sh

# Option B: Déploiement manuel
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Durée estimée:** 15-20 minutes

**Outputs importants à noter:**
- `vpc_id`: ID du VPC
- `database_endpoint`: Endpoint de la base de données
- `api_endpoint`: Endpoint de l'API
- `frontend_s3_bucket`: Bucket S3 pour le frontend

### Phase 4: Configuration Post-Déploiement ⚙️

#### 4.1 Créer les Repositories ECR

```bash
# API
aws ecr create-repository \
  --repository-name hirewire-api \
  --region us-east-1

# Airflow
aws ecr create-repository \
  --repository-name hirewire-airflow \
  --region us-east-1

# DBT
aws ecr create-repository \
  --repository-name hirewire-dbt \
  --region us-east-1
```

#### 4.2 Build et Push des Images Docker

```bash
# Se connecter à ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com

# Build et push API
cd backend
docker build -t hirewire-api .
docker tag hirewire-api:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hirewire-api:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hirewire-api:latest

# Build et push Airflow
cd ../
docker build -f .infra/docker/airflow.Dockerfile -t hirewire-airflow .
docker tag hirewire-airflow:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hirewire-airflow:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hirewire-airflow:latest

# Build et push DBT
docker build -f .infra/docker/dbt.Dockerfile -t hirewire-dbt .
docker tag hirewire-dbt:latest \
  ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hirewire-dbt:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/hirewire-dbt:latest
```

#### 4.3 Initialiser la Base de Données

```bash
# Récupérer l'endpoint de la base de données
DB_ENDPOINT=$(terraform output -raw database_endpoint)

# Se connecter via un bastion ou directement si accessible
# Option 1: Via psql local (si accessible)
psql -h $DB_ENDPOINT -U hirewire_admin -d hirewire

# Option 2: Via ECS Task (recommandé pour production)
aws ecs run-task \
  --cluster hirewire-cluster-prod \
  --task-definition hirewire-db-migration \
  --launch-type FARGATE

# Exécuter les migrations
\i sql/postgres/schema.sql
```

#### 4.4 Déployer le Frontend

```bash
cd frontend

# Build le frontend
npm run build

# Upload vers S3
FRONTEND_BUCKET=$(terraform output -raw frontend_s3_bucket)
aws s3 sync dist/ s3://${FRONTEND_BUCKET}/ --delete

# Invalider le cache CloudFront
CLOUDFRONT_ID=$(terraform output -raw frontend_cloudfront_id)
aws cloudfront create-invalidation \
  --distribution-id $CLOUDFRONT_ID \
  --paths "/*"
```

### Phase 5: Configuration DNS (Optionnel) 🌐

Si vous avez un domaine custom :

```bash
# 1. Récupérer le nameserver de Route53
aws route53 list-hosted-zones

# 2. Chez votre registrar, pointer les nameservers vers AWS Route53

# 3. Créer un certificat SSL
aws acm request-certificate \
  --domain-name hirewire.example.com \
  --validation-method DNS \
  --region us-east-1

# 4. Valider le certificat via DNS
# (suivre les instructions dans la console AWS)
```

### Phase 6: Monitoring et Alertes 📊

#### 6.1 Vérifier les Budgets

```bash
# Lister les budgets
aws budgets describe-budgets \
  --account-id $(aws sts get-caller-identity --query Account --output text)
```

#### 6.2 Accéder aux Dashboards CloudWatch

1. Aller sur AWS Console → CloudWatch → Dashboards
2. Ouvrir le dashboard `HireWire-prod`
3. Vérifier les métriques:
   - ECS CPU/Memory
   - RDS Connections/Latency
   - ALB Request Count/Latency

#### 6.3 Configurer SNS pour les Alertes

```bash
# S'abonner aux notifications SNS
aws sns subscribe \
  --topic-arn arn:aws:sns:us-east-1:ACCOUNT_ID:hirewire-alerts-prod \
  --protocol email \
  --notification-endpoint votre-email@example.com

# Confirmer l'abonnement dans l'email reçu
```

### Phase 7: Tests de Fonctionnement ✅

#### 7.1 Tester l'API

```bash
API_ENDPOINT=$(terraform output -raw api_endpoint)

# Health check
curl https://${API_ENDPOINT}/health

# Test login
curl -X POST https://${API_ENDPOINT}/api/v1/auth/login/json \
  -H "Content-Type: application/json" \
  -d '{"username":"admin@hirewire.com","password":"your-password"}'
```

#### 7.2 Tester le Frontend

```bash
FRONTEND_URL=$(terraform output -raw frontend_cloudfront_url)
curl -I https://${FRONTEND_URL}

# Devrait retourner 200 OK
```

#### 7.3 Vérifier Airflow

```bash
# Se connecter au webserver Airflow via port-forward
aws ecs execute-command \
  --cluster hirewire-cluster-prod \
  --task TASK_ID \
  --container airflow-webserver \
  --interactive \
  --command "/bin/bash"

# Dans le container
airflow dags list
airflow dags trigger daily_etl_pipeline
```

## 🔄 Déploiements Continus

### Setup GitHub Actions (Recommandé)

Créer `.github/workflows/deploy-aws.yml`:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Build and push Docker images
        run: |
          ./scripts/build-and-push.sh

      - name: Update ECS services
        run: |
          aws ecs update-service \
            --cluster hirewire-cluster-prod \
            --service hirewire-api \
            --force-new-deployment
```

## 📊 Monitoring des Coûts en Production

### Tableau de Bord des Coûts

```bash
# Voir les coûts des 30 derniers jours
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '30 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE \
  | jq '.ResultsByTime[].Groups | sort_by(.Metrics.BlendedCost.Amount | tonumber) | reverse'
```

### Alertes Coûts Configurées

1. **Email à 80% du budget** ($120)
2. **Email à 100% du budget** ($150)
3. **Alerte CloudWatch si ACU Aurora > 1.5**
4. **Alerte CloudWatch si ECS Tasks > 5**

## 🗑️ Rollback / Destruction

### Rollback d'une Version

```bash
# Revenir à l'image Docker précédente
aws ecs update-service \
  --cluster hirewire-cluster-prod \
  --service hirewire-api \
  --task-definition hirewire-api:PREVIOUS_REVISION
```

### Destruction Complète

```bash
# ⚠️  ATTENTION: Cela va tout supprimer !

# 1. Vider les buckets S3
aws s3 rm s3://$(terraform output -raw frontend_s3_bucket) --recursive
aws s3 rm s3://$(terraform output -raw airflow_s3_bucket) --recursive
aws s3 rm s3://$(terraform output -raw analytics_s3_bucket) --recursive

# 2. Désactiver la protection contre la suppression
aws rds modify-db-cluster \
  --db-cluster-identifier $(terraform output -raw database_cluster_id) \
  --no-deletion-protection

# 3. Détruire l'infrastructure
terraform destroy

# Durée: ~15-20 minutes
```

## 📈 Scaling

### Auto-Scaling Automatique

L'infrastructure est déjà configurée pour auto-scaler :

**API (ECS Fargate):**
- Min: 1 task
- Max: 3 tasks
- Trigger: CPU > 70% pendant 2 minutes

**Database (Aurora Serverless v2):**
- Min: 0.5 ACU (~$44/month)
- Max: 2 ACU (~$175/month)
- Trigger: Automatique selon charge

### Scaling Manuel

```bash
# Augmenter le nombre de tasks API
aws ecs update-service \
  --cluster hirewire-cluster-prod \
  --service hirewire-api \
  --desired-count 3

# Augmenter le max ACU de la base
aws rds modify-db-cluster \
  --db-cluster-identifier hirewire-cluster-prod \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=4
```

## 🆘 Support et Troubleshooting

### Logs CloudWatch

```bash
# API logs
aws logs tail /ecs/hirewire-api-prod --follow

# Airflow logs
aws logs tail /ecs/hirewire-airflow-prod --follow

# RDS logs
aws rds describe-db-log-files \
  --db-instance-identifier hirewire-instance-prod
```

### Shell dans un Container ECS

```bash
# Lister les tasks en cours
aws ecs list-tasks \
  --cluster hirewire-cluster-prod \
  --service-name hirewire-api

# Se connecter à une task
aws ecs execute-command \
  --cluster hirewire-cluster-prod \
  --task TASK_ARN \
  --container api \
  --interactive \
  --command "/bin/bash"
```

### Backup Manuel de la Base

```bash
# Créer un snapshot
aws rds create-db-cluster-snapshot \
  --db-cluster-snapshot-identifier hirewire-manual-$(date +%Y%m%d) \
  --db-cluster-identifier hirewire-cluster-prod
```

## 📚 Ressources Additionnelles

- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/intro.html)
- [Aurora Serverless v2 Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.best-practices.html)

## ✅ Checklist Post-Déploiement

- [ ] Infrastructure déployée avec succès
- [ ] Images Docker poussées sur ECR
- [ ] Base de données initialisée
- [ ] Frontend déployé sur S3/CloudFront
- [ ] Tests API réussis
- [ ] Tests Frontend réussis
- [ ] Airflow DAGs visibles et fonctionnels
- [ ] Budgets AWS configurés
- [ ] Alertes SNS confirmées
- [ ] DNS configuré (si applicable)
- [ ] SSL/TLS configuré (si applicable)
- [ ] Documentation mise à jour
- [ ] Backup automatique vérifié
- [ ] Monitoring CloudWatch actif
