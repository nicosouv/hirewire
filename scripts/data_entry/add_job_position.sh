#!/bin/bash
# Ajouter un poste
# Usage: ./scripts/add_job_position.sh [company_name] [titre] [department] [level] [salary_min] [salary_max]

set -e

# Function to execute SQL
exec_sql() {
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "$1"
}

# Function to get company ID by name
get_company_id() {
    local company_name="$1"
    exec_sql "SELECT id FROM hirewire.companies WHERE name = '$company_name';" | grep -o '[0-9]\+' | head -1
}

if [ $# -eq 0 ]; then
    # Mode interactif
    echo "💼 Ajouter un poste"
    echo "==================="
    
    # List companies
    echo "Entreprises disponibles:"
    exec_sql "SELECT id, name FROM hirewire.companies ORDER BY name;" | grep -E '^[[:space:]]*[0-9]+' | sed 's/^[[:space:]]*/- /'
    echo ""
    
    read -p "Nom de l'entreprise: " company_name
    read -p "Titre du poste: " title
    read -p "Département [Engineering]: " department
    department=${department:-Engineering}
    read -p "Level (junior/mid/senior/lead): " level
    read -p "Type d'emploi [full-time]: " employment_type
    employment_type=${employment_type:-full-time}
    read -p "Politique remote [hybrid]: " remote_policy
    remote_policy=${remote_policy:-hybrid}
    read -p "Salaire min (€): " salary_min
    read -p "Salaire max (€): " salary_max
else
    # Mode commande
    company_name="$1"
    title="$2"
    department="${3:-Engineering}"
    level="$4"
    employment_type="${5:-full-time}"
    remote_policy="${6:-hybrid}"
    salary_min="$7"
    salary_max="$8"
fi

if [[ -z "$company_name" || -z "$title" ]]; then
    echo "❌ Le nom de l'entreprise et le titre sont obligatoires"
    exit 1
fi

# Get company ID
company_id=$(get_company_id "$company_name")
if [[ -z "$company_id" ]]; then
    echo "❌ Entreprise '$company_name' non trouvée"
    echo "💡 Ajoutez-la d'abord avec: ./scripts/add_company.sh '$company_name'"
    exit 1
fi

# Build SQL
sql="INSERT INTO hirewire.job_positions (company_id, title, department, level, employment_type, remote_policy"
values="VALUES ($company_id, '$title', '$department', '$level', '$employment_type', '$remote_policy'"

if [[ -n "$salary_min" ]]; then
    sql="$sql, salary_min"
    values="$values, $salary_min"
fi

if [[ -n "$salary_max" ]]; then
    sql="$sql, salary_max"
    values="$values, $salary_max"
fi

sql="$sql) $values) RETURNING id;"

# Insert job position
result=$(exec_sql "$sql")
position_id=$(echo "$result" | grep -o '[0-9]\+' | head -1)

echo "✅ Poste '$title' chez '$company_name' ajouté (ID: $position_id)"

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage en ligne de commande:"
    echo "./scripts/add_job_position.sh 'TechCorp' 'Senior Developer' 'Engineering' 'senior' 'full-time' 'remote' 65000 85000"
fi