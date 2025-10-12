#!/bin/bash

# ============================================
# HireWire AWS Cost Estimation Calculator
# ============================================

echo "💰 HireWire AWS Cost Estimation"
echo "======================================"
echo ""

# Region pricing (us-east-1)
FARGATE_VCPU_PRICE=0.04048
FARGATE_GB_PRICE=0.004445
AURORA_ACU_PRICE=0.12
S3_STORAGE_PRICE=0.023
CLOUDFRONT_REQUESTS_PRICE=0.0075

# Monthly hours
HOURS_PER_MONTH=730

# ============================================
# Frontend (S3 + CloudFront)
# ============================================
S3_STORAGE_GB=10
CLOUDFRONT_REQUESTS=100000  # 100K requests

FRONTEND_S3=$(echo "scale=2; $S3_STORAGE_GB * $S3_STORAGE_PRICE" | bc)
FRONTEND_CF=$(echo "scale=2; ($CLOUDFRONT_REQUESTS / 10000) * $CLOUDFRONT_REQUESTS_PRICE" | bc)
FRONTEND_TOTAL=$(echo "scale=2; $FRONTEND_S3 + $FRONTEND_CF" | bc)

# ============================================
# API (ECS Fargate)
# ============================================
API_VCPU=0.5
API_GB=1
API_INSTANCES=1

API_COST=$(echo "scale=2; $API_INSTANCES * (($API_VCPU * $HOURS_PER_MONTH * $FARGATE_VCPU_PRICE) + ($API_GB * $HOURS_PER_MONTH * $FARGATE_GB_PRICE))" | bc)

# ============================================
# Database (Aurora Serverless v2)
# ============================================
DB_AVG_ACU=0.7  # Average between min 0.5 and occasional spikes

DB_COST=$(echo "scale=2; $DB_AVG_ACU * $HOURS_PER_MONTH * $AURORA_ACU_PRICE" | bc)
DB_STORAGE_GB=20
DB_STORAGE_COST=$(echo "scale=2; $DB_STORAGE_GB * 0.10" | bc)
DB_TOTAL=$(echo "scale=2; $DB_COST + $DB_STORAGE_COST" | bc)

# ============================================
# Airflow (ECS Fargate)
# ============================================
AIRFLOW_VCPU=1
AIRFLOW_GB=2
AIRFLOW_INSTANCES=3  # Webserver, Scheduler, Worker

AIRFLOW_COST=$(echo "scale=2; $AIRFLOW_INSTANCES * (($AIRFLOW_VCPU * $HOURS_PER_MONTH * $FARGATE_VCPU_PRICE) + ($AIRFLOW_GB * $HOURS_PER_MONTH * $FARGATE_GB_PRICE))" | bc)

# ============================================
# DBT Analytics (ECS Fargate)
# ============================================
DBT_VCPU=0.5
DBT_GB=1
DBT_HOURS_MONTH=50  # Runs only during ETL windows

DBT_COST=$(echo "scale=2; (($DBT_VCPU * $DBT_HOURS_MONTH * $FARGATE_VCPU_PRICE) + ($DBT_GB * $DBT_HOURS_MONTH * $FARGATE_GB_PRICE))" | bc)

# ============================================
# Storage (S3 + EBS)
# ============================================
S3_ANALYTICS_GB=30
S3_LOGS_GB=10
EBS_GB=20

STORAGE_S3=$(echo "scale=2; ($S3_ANALYTICS_GB + $S3_LOGS_GB) * $S3_STORAGE_PRICE" | bc)
STORAGE_EBS=$(echo "scale=2; $EBS_GB * 0.10" | bc)
STORAGE_TOTAL=$(echo "scale=2; $STORAGE_S3 + $STORAGE_EBS" | bc)

# ============================================
# Networking
# ============================================
ROUTE53_ZONES=1
VPC_ENDPOINTS=3

NETWORK_ROUTE53=$(echo "scale=2; $ROUTE53_ZONES * 0.50" | bc)
NETWORK_VPC_ENDPOINTS=$(echo "scale=2; $VPC_ENDPOINTS * 0.01 * $HOURS_PER_MONTH" | bc)
NETWORK_DATA_TRANSFER=5  # Estimated
NETWORK_TOTAL=$(echo "scale=2; $NETWORK_ROUTE53 + $NETWORK_VPC_ENDPOINTS + $NETWORK_DATA_TRANSFER" | bc)

# ============================================
# Total Cost
# ============================================
TOTAL_COST=$(echo "scale=2; $FRONTEND_TOTAL + $API_COST + $DB_TOTAL + $AIRFLOW_COST + $DBT_COST + $STORAGE_TOTAL + $NETWORK_TOTAL" | bc)

# ============================================
# Display Results
# ============================================

printf "%-25s %-35s %10s\n" "Service" "Configuration" "Cost/Month"
echo "------------------------------------------------------------------------"
printf "%-25s %-35s %10s\n" "Frontend" "S3 ($S3_STORAGE_GB GB) + CloudFront (${CLOUDFRONT_REQUESTS} req)" "\$$FRONTEND_TOTAL"
printf "%-25s %-35s %10s\n" "API" "ECS ($API_VCPU vCPU, ${API_GB}GB)" "\$$API_COST"
printf "%-25s %-35s %10s\n" "Database" "Aurora Serverless v2 (${DB_AVG_ACU} ACU avg)" "\$$DB_TOTAL"
printf "%-25s %-35s %10s\n" "Airflow" "ECS x3 ($AIRFLOW_VCPU vCPU, ${AIRFLOW_GB}GB each)" "\$$AIRFLOW_COST"
printf "%-25s %-35s %10s\n" "DBT Analytics" "ECS ($DBT_VCPU vCPU, ${DBT_GB}GB, ${DBT_HOURS_MONTH}h/mo)" "\$$DBT_COST"
printf "%-25s %-35s %10s\n" "Storage" "S3 (${S3_ANALYTICS_GB}GB) + EBS (${EBS_GB}GB)" "\$$STORAGE_TOTAL"
printf "%-25s %-35s %10s\n" "Networking" "Route53 + VPC Endpoints" "\$$NETWORK_TOTAL"
echo "------------------------------------------------------------------------"
printf "%-25s %-35s %10s\n" "TOTAL ESTIMATED" "" "\$$TOTAL_COST"
echo ""

# ============================================
# Cost Breakdown Pie Chart (ASCII)
# ============================================

AIRFLOW_PCT=$(echo "scale=0; $AIRFLOW_COST / $TOTAL_COST * 100" | bc)
DB_PCT=$(echo "scale=0; $DB_TOTAL / $TOTAL_COST * 100" | bc)
API_PCT=$(echo "scale=0; $API_COST / $TOTAL_COST * 100" | bc)

echo "📊 Cost Distribution:"
echo "  Airflow:     ${AIRFLOW_PCT}% (████████████)"
echo "  Database:    ${DB_PCT}% (██████████)"
echo "  API:         ${API_PCT}% (████)"
echo "  Analytics:   $(echo "scale=0; $DBT_COST / $TOTAL_COST * 100" | bc)% (██)"
echo "  Storage:     $(echo "scale=0; $STORAGE_TOTAL / $TOTAL_COST * 100" | bc)% (██)"
echo "  Networking:  $(echo "scale=0; $NETWORK_TOTAL / $TOTAL_COST * 100" | bc)% (██)"
echo "  Frontend:    $(echo "scale=0; $FRONTEND_TOTAL / $TOTAL_COST * 100" | bc)% (█)"
echo ""

# ============================================
# Cost Optimization Recommendations
# ============================================

echo "💡 Cost Optimization Opportunities:"
echo ""
echo "1. Airflow Alternative (-\$25/month):"
echo "   Replace ECS Airflow with EventBridge Scheduler + Lambda"
echo "   New cost: ~\$10/month | Savings: \$25/month"
echo ""
echo "2. Database Optimization (-\$15/month):"
echo "   Use db.t4g.micro instead of Aurora Serverless v2"
echo "   New cost: ~\$15/month | Savings: \$35/month"
echo "   ⚠️  Less auto-scaling, fixed capacity"
echo ""
echo "3. Fargate Spot Instances (-\$20/month):"
echo "   Use Fargate Spot for non-critical workloads (70% discount)"
echo "   Savings: ~\$20/month"
echo "   ⚠️  May be interrupted occasionally"
echo ""
echo "4. Reserved Capacity (-\$30/month):"
echo "   Commit to 1-year Savings Plan"
echo "   Savings: ~\$30/month (21% discount)"
echo ""

OPTIMIZED_TOTAL=$(echo "scale=2; $TOTAL_COST - 25 - 15 - 20" | bc)
echo "🎯 Optimized Total: \$$OPTIMIZED_TOTAL/month (with all optimizations)"
echo ""

# ============================================
# AWS Free Tier Benefit (First Year)
# ============================================

echo "🆓 AWS Free Tier Benefits (First 12 months):"
echo "  - 750 hours/month RDS (db.t2.micro)"
echo "  - 5 GB S3 storage"
echo "  - 1 TB CloudFront data transfer"
echo "  - 1M Lambda requests"
echo ""
echo "  Estimated First Year Savings: ~\$20/month"
echo ""

# ============================================
# Cost Comparison
# ============================================

echo "📈 Cost Comparison:"
printf "%-30s %10s\n" "Configuration" "Monthly Cost"
echo "--------------------------------------------"
printf "%-30s %10s\n" "Current (Local Docker)" "\$0"
printf "%-30s %10s\n" "AWS Standard" "\$$TOTAL_COST"
printf "%-30s %10s\n" "AWS Optimized" "\$$OPTIMIZED_TOTAL"
printf "%-30s %10s\n" "AWS Free Tier (Year 1)" "\$$(echo "$TOTAL_COST - 20" | bc)"
echo ""
