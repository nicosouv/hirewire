# HireWire AWS Infrastructure

Infrastructure as Code (Terraform) pour déployer HireWire sur AWS avec optimisation des coûts.

## 💰 Coût Estimé : $100-150/mois

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────────┐             │
│  │   Route53    │────────>│   CloudFront     │             │
│  │     DNS      │         │      (CDN)       │             │
│  └──────────────┘         └─────────┬────────┘             │
│                                      │                       │
│                                      v                       │
│                           ┌──────────────────┐              │
│                           │   S3 Bucket      │              │
│                           │   (Frontend)     │              │
│                           └──────────────────┘              │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │                      VPC                              │  │
│  │  ┌────────────────────────────────────────────────┐  │  │
│  │  │         Public Subnets (AZ-a, AZ-b)            │  │  │
│  │  │  ┌─────────────────┐                           │  │  │
│  │  │  │   ALB (API)     │                           │  │  │
│  │  │  └────────┬────────┘                           │  │  │
│  │  └───────────┼─────────────────────────────────────┘  │  │
│  │              │                                          │  │
│  │  ┌───────────┼─────────────────────────────────────┐  │  │
│  │  │         Private Subnets (AZ-a, AZ-b)            │  │  │
│  │  │              │                                   │  │  │
│  │  │  ┌───────────v──────────┐  ┌──────────────┐   │  │  │
│  │  │  │  ECS Fargate         │  │  ECS Fargate │   │  │  │
│  │  │  │  - API (0.5 vCPU)    │  │  - Airflow   │   │  │  │
│  │  │  │  - DBT (0.5 vCPU)    │  │    (3x1 vCPU)│   │  │  │
│  │  │  └──────────────────────┘  └──────────────┘   │  │  │
│  │  │                                                  │  │  │
│  │  │  ┌──────────────────────────────────────────┐  │  │  │
│  │  │  │  Aurora Serverless v2 PostgreSQL         │  │  │  │
│  │  │  │  - Auto-scaling: 0.5-2 ACU               │  │  │  │
│  │  │  │  - Encrypted (KMS)                       │  │  │  │
│  │  │  └──────────────────────────────────────────┘  │  │  │
│  │  │                                                  │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │                                                          │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │   VPC Endpoints (No NAT Gateway!)                │  │  │
│  │  │   - S3 Gateway Endpoint                          │  │  │
│  │  │   - ECR API/DKR Endpoints                        │  │  │
│  │  │   - CloudWatch Logs Endpoint                     │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │   S3 Buckets                                          │  │
│  │   - Airflow DAGs/Logs                                 │  │
│  │   - DuckDB Analytics Data                             │  │
│  │   - Terraform State (encrypted)                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## 📊 Estimation Détaillée des Coûts

### Coûts Mensuels par Service

| Service | Configuration | Prix unitaire | Quantité | Total/mois |
|---------|--------------|---------------|----------|------------|
| **Compute** | | | | **$68** |
| ECS Fargate (API) | 0.5 vCPU, 1GB RAM | $0.04048/vCPU-h + $0.004445/GB-h | 730h | $18 |
| ECS Fargate (Airflow x3) | 1 vCPU, 2GB RAM each | $0.04048/vCPU-h + $0.004445/GB-h | 2190h | $35 |
| ECS Fargate (DBT) | 0.5 vCPU, 1GB RAM | $0.04048/vCPU-h + $0.004445/GB-h | 50h | $3 |
| **Database** | | | | **$50** |
| Aurora Serverless v2 | 0.5-2 ACU auto-scaling | $0.12/ACU-hour | ~583 ACU-hours | $48 |
| Database Storage | 20GB | $0.10/GB-month | 20GB | $2 |
| **Storage** | | | | **$8** |
| S3 (Frontend) | Standard storage | $0.023/GB | 10GB | $0.23 |
| S3 (Analytics) | Intelligent-Tiering | $0.023/GB | 30GB | $0.69 |
| S3 (Logs) | Standard storage | $0.023/GB | 10GB | $0.23 |
| EBS Volumes | gp3 | $0.08/GB-month | 20GB | $1.60 |
| S3 Requests | PUT/GET | Various | 100K | $0.50 |
| **Networking** | | | | **$12** |
| Route53 | Hosted zone | $0.50/zone | 1 | $0.50 |
| VPC Endpoints | Interface endpoints | $0.01/hour | 3 x 730h | $21.90 |
| Data Transfer | Outbound | $0.09/GB | 5GB | $0.45 |
| **Frontend (CDN)** | | | | **$8** |
| CloudFront | Requests + data transfer | Various | 100K req + 10GB | $8 |
| | | | | |
| **TOTAL MENSUEL** | | | | **$146** |

### Répartition des Coûts

```
Compute (47%):     ████████████████████ $68
Database (34%):    ██████████████ $50
Networking (15%):  ███████ $22
Storage (4%):      ██ $6
```

## 🚀 Déploiement

### Prérequis

```bash
# Installer Terraform
brew install terraform

# Installer AWS CLI
brew install awscli

# Configurer AWS CLI
aws configure
# AWS Access Key ID: [YOUR_KEY]
# AWS Secret Access Key: [YOUR_SECRET]
# Default region: us-east-1
# Default output format: json
```

### Étapes de Déploiement

#### 1. Estimation des Coûts

```bash
cd terraform/aws
./scripts/cost-estimate.sh
```

Cela affichera une estimation détaillée des coûts mensuels.

#### 2. Configuration

```bash
# Copier le fichier d'exemple
cp terraform.tfvars.example terraform.tfvars

# Éditer avec vos valeurs
nano terraform.tfvars
```

**Variables importantes à configurer :**

```hcl
owner_email        = "votre-email@example.com"
db_master_password = "STRONG-PASSWORD-16-CHARS-MIN"
monthly_budget_limit = 150
```

#### 3. Déploiement Automatique

```bash
./scripts/deploy.sh
```

Ce script va :
1. ✅ Vérifier les prérequis
2. 💰 Afficher l'estimation des coûts
3. 🔧 Initialiser Terraform
4. 📋 Créer un plan d'exécution
5. 🚀 Déployer l'infrastructure
6. 💰 Configurer les alertes budgétaires
7. 📊 Afficher les outputs

#### 4. Déploiement Manuel (étape par étape)

```bash
# Initialiser
terraform init

# Planifier
terraform plan -out=tfplan

# Appliquer
terraform apply tfplan

# Voir les outputs
terraform output
```

## 💡 Optimisation des Coûts

### Optimisations Déjà Implémentées

✅ **Pas de NAT Gateway** (-$32/mois)
- Utilisation de VPC Endpoints pour S3, ECR, CloudWatch

✅ **Aurora Serverless v2** avec auto-scaling
- Scale down à 0.5 ACU quand inactif
- Scale up à 2 ACU sous charge

✅ **ECS Fargate** avec capacité minimale
- API: 0.5 vCPU, 1GB RAM
- DBT: exécution ponctuelle uniquement

✅ **S3 Intelligent-Tiering**
- Déplace automatiquement les données froides vers stockage moins cher

### Optimisations Additionnelles Possibles

#### Option 1: Remplacer Airflow par EventBridge + Lambda
**Économie: ~$25/mois**

```hcl
# Dans terraform.tfvars
enable_airflow_ecs = false  # Utiliser EventBridge à la place
```

- ✅ Moins cher (~$10/mois)
- ❌ Moins de fonctionnalités qu'Airflow

#### Option 2: Utiliser Fargate Spot
**Économie: ~$20/mois (70% de réduction)**

```hcl
# Dans terraform.tfvars
enable_fargate_spot = true
```

- ✅ 70% moins cher
- ❌ Peut être interrompu occasionnellement

#### Option 3: Utiliser db.t4g.micro au lieu d'Aurora
**Économie: ~$35/mois**

```hcl
# Dans terraform.tfvars
database_type = "rds_micro"  # Au lieu de "aurora_serverless_v2"
```

- ✅ Beaucoup moins cher ($15/mois)
- ❌ Pas d'auto-scaling
- ❌ Moins performant

#### Option 4: Savings Plans (1 an)
**Économie: ~$30/mois (21% de réduction)**

Directement dans AWS Console :
1. Aller dans AWS Cost Management
2. Activer Savings Plans
3. Commitment 1 an : -21%
4. Commitment 3 ans : -35%

### Tableau Comparatif

| Configuration | Coût Mensuel | Avantages | Inconvénients |
|---------------|--------------|-----------|---------------|
| **Standard** (actuelle) | $146 | Robuste, auto-scaling | Coût moyen |
| **Optimisée Lambda** | $121 | -$25, serverless | Moins de features Airflow |
| **Optimisée Spot** | $126 | -$20, même infra | Interruptions possibles |
| **Budget Serré** | $91 | -$55, très économique | RDS micro, pas d'auto-scaling |
| **Avec Savings Plan** | $116 | -$30, pas de changement | Commitment 1 an |

## 🔒 Sécurité

### Fonctionnalités de Sécurité Implémentées

- ✅ Base de données dans sous-réseaux privés
- ✅ Chiffrement au repos (KMS) pour Aurora
- ✅ Chiffrement en transit (TLS)
- ✅ Security Groups avec règles strictes
- ✅ IAM Roles avec principe du moindre privilège
- ✅ Secrets Manager pour credentials
- ✅ CloudWatch Logs avec rétention configurée
- ✅ VPC Flow Logs (optionnel)

## 📊 Monitoring

### CloudWatch Dashboards

Le module crée automatiquement des dashboards pour :
- Métriques ECS (CPU, mémoire, nombre de tâches)
- Métriques Aurora (connexions, latence, ACU utilisés)
- Métriques ALB (requêtes, erreurs, latence)
- Coûts quotidiens

### Alertes Configurées

- 🚨 Budget à 80% ($120/mois)
- 🚨 CPU ECS > 80%
- 🚨 Latence API > 1s
- 🚨 Erreurs 5xx > 10/min
- 🚨 Database connections > 90%

## 🗑️ Destruction

```bash
# Détruire toute l'infrastructure
terraform destroy

# ⚠️  ATTENTION : Cette commande va supprimer :
# - Tous les containers ECS
# - La base de données Aurora (snapshot final créé si prod)
# - Tous les buckets S3 (si vides)
# - Tous les logs CloudWatch
```

## 📖 Documentation des Modules

### Modules Terraform

- `modules/vpc` - VPC avec sous-réseaux publics/privés et VPC Endpoints
- `modules/database` - Aurora Serverless v2 PostgreSQL
- `modules/ecs` - Cluster ECS Fargate
- `modules/api` - Service API FastAPI
- `modules/airflow` - Orchestration Airflow sur ECS
- `modules/analytics` - DBT + DuckDB sur ECS
- `modules/frontend` - S3 + CloudFront
- `modules/security` - Security Groups
- `modules/monitoring` - CloudWatch + Budgets

### Commandes Utiles

```bash
# Voir l'état actuel
terraform state list

# Voir un output spécifique
terraform output api_endpoint

# Importer une ressource existante
terraform import module.vpc.aws_vpc.main vpc-12345678

# Valider la configuration
terraform validate

# Formatter le code
terraform fmt -recursive

# Voir le graph de dépendances
terraform graph | dot -Tsvg > graph.svg
```

## 🆘 Troubleshooting

### Problème: "Error creating Aurora Cluster: InsufficientFreeAddressesInSubnet"

**Solution:** Augmenter la taille des sous-réseaux privés dans `variables.tf`

```hcl
private_subnets = ["10.0.11.0/23", "10.0.13.0/23"]  # Au lieu de /24
```

### Problème: "Error: error creating ECS Service: InvalidParameterException"

**Solution:** Vérifier que l'image Docker est bien poussée dans ECR

```bash
# Se connecter à ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Construire et pousser
docker build -t hirewire-api ./backend
docker tag hirewire-api:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/hirewire-api:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/hirewire-api:latest
```

### Problème: Coûts plus élevés que prévu

**Solution:** Activer Cost Explorer et identifier les services coûteux

```bash
# Voir les coûts des 7 derniers jours
aws ce get-cost-and-usage \
  --time-period Start=$(date -d '7 days ago' +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

## 📚 Ressources

- [AWS Pricing Calculator](https://calculator.aws/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Aurora Serverless v2 Documentation](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [ECS Fargate Pricing](https://aws.amazon.com/fargate/pricing/)

## 📝 License

MIT
