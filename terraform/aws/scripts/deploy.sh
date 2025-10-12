#!/bin/bash
set -e

# ============================================
# HireWire AWS Deployment Script
# ============================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(dirname "$SCRIPT_DIR")"

echo "🚀 HireWire AWS Infrastructure Deployment"
echo "=========================================="
echo ""

# Check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."

    if ! command -v terraform &> /dev/null; then
        echo "❌ Terraform not found. Please install Terraform 1.5.0+"
        exit 1
    fi

    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install AWS CLI"
        exit 1
    fi

    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS credentials not configured. Run 'aws configure'"
        exit 1
    fi

    echo "✅ Prerequisites check passed"
    echo ""
}

# Estimate costs
estimate_costs() {
    echo "💰 Estimating Monthly Costs..."
    echo "======================================"

    cat << EOF
Service                 Configuration                Cost/Month (USD)
----------------------------------------------------------------------
Frontend                S3 + CloudFront              \$8
API                     ECS Fargate (0.5 vCPU, 1GB)  \$18
Database                Aurora Serverless v2 (0.5-1) \$50
Airflow                 ECS Fargate (1 vCPU, 2GB)    \$35
DBT Analytics           ECS Fargate (0.5 vCPU, 1GB)  \$15
Storage                 S3 + EBS (50GB)              \$8
Networking              VPC Endpoints + Route53      \$12
----------------------------------------------------------------------
TOTAL ESTIMATED                                      \$146/month

📊 Cost Breakdown:
   - Compute (ECS):        \$68/month (47%)
   - Database (Aurora):    \$50/month (34%)
   - Storage (S3/EBS):     \$8/month  (5%)
   - Networking:           \$12/month (8%)
   - Frontend (CDN):       \$8/month  (6%)

💡 Cost Optimization Tips:
   ✓ No NAT Gateway (saves \$32/month)
   ✓ Aurora Serverless v2 auto-scales down when idle
   ✓ ECS Fargate optimized for minimal capacity
   ✓ S3 Intelligent-Tiering enabled
   ✓ CloudWatch logs retention set to 7 days

⚠️  Note: Actual costs may vary based on:
   - Data transfer volumes
   - API request rates
   - Database activity patterns
   - Backup storage size

EOF
    echo ""
}

# Initialize Terraform
init_terraform() {
    echo "🔧 Initializing Terraform..."
    cd "$TERRAFORM_DIR"

    if [ ! -f "terraform.tfvars" ]; then
        echo "⚠️  terraform.tfvars not found"
        echo "📝 Creating from template..."
        cp terraform.tfvars.example terraform.tfvars
        echo ""
        echo "❗ IMPORTANT: Edit terraform.tfvars and set your values:"
        echo "   - owner_email"
        echo "   - db_master_password"
        echo "   - domain_name (optional)"
        echo ""
        read -p "Press Enter when you've edited terraform.tfvars..."
    fi

    terraform init
    echo "✅ Terraform initialized"
    echo ""
}

# Plan deployment
plan_deployment() {
    echo "📋 Planning deployment..."
    cd "$TERRAFORM_DIR"
    terraform plan -out=tfplan
    echo ""
    echo "✅ Plan created: tfplan"
    echo ""
}

# Apply deployment
apply_deployment() {
    echo "🚀 Applying deployment..."
    cd "$TERRAFORM_DIR"

    echo "⚠️  This will create resources on AWS and incur costs!"
    echo "   Estimated monthly cost: \$146"
    echo ""
    read -p "Do you want to proceed? (yes/no): " confirm

    if [ "$confirm" != "yes" ]; then
        echo "❌ Deployment cancelled"
        exit 0
    fi

    terraform apply tfplan
    echo ""
    echo "✅ Deployment complete!"
    echo ""
}

# Show outputs
show_outputs() {
    echo "📊 Deployment Outputs"
    echo "======================================"
    cd "$TERRAFORM_DIR"
    terraform output
    echo ""
}

# Setup budget alerts
setup_budget() {
    echo "💰 Setting up AWS Budget alerts..."

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    ALERT_EMAIL=$(terraform output -raw owner_email 2>/dev/null || echo "not-set@example.com")

    aws budgets create-budget \
        --account-id "$ACCOUNT_ID" \
        --budget "{
            \"BudgetName\": \"HireWire-Monthly-Budget\",
            \"BudgetLimit\": {
                \"Amount\": \"150\",
                \"Unit\": \"USD\"
            },
            \"TimeUnit\": \"MONTHLY\",
            \"BudgetType\": \"COST\"
        }" \
        --notifications-with-subscribers "[
            {
                \"Notification\": {
                    \"NotificationType\": \"ACTUAL\",
                    \"ComparisonOperator\": \"GREATER_THAN\",
                    \"Threshold\": 80
                },
                \"Subscribers\": [
                    {
                        \"SubscriptionType\": \"EMAIL\",
                        \"Address\": \"$ALERT_EMAIL\"
                    }
                ]
            }
        ]" 2>/dev/null || echo "⚠️  Budget already exists or failed to create"

    echo "✅ Budget alert configured (80% threshold at \$120/month)"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    estimate_costs

    echo "📝 Deployment Steps:"
    echo "  1. Initialize Terraform"
    echo "  2. Plan deployment"
    echo "  3. Apply deployment"
    echo "  4. Setup budget alerts"
    echo ""

    read -p "Start deployment? (yes/no): " start
    if [ "$start" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi

    init_terraform
    plan_deployment
    apply_deployment
    setup_budget
    show_outputs

    echo "🎉 Deployment Complete!"
    echo ""
    echo "📚 Next Steps:"
    echo "  1. Build and push Docker images to ECR"
    echo "  2. Deploy application containers to ECS"
    echo "  3. Upload frontend to S3"
    echo "  4. Configure DNS (if using custom domain)"
    echo ""
    echo "📖 Documentation: See terraform/aws/README.md"
}

main "$@"
