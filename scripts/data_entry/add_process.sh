#!/bin/bash
# Ajouter un processus d'entretien
# Usage: ./scripts/add_process.sh [company_name] [job_title] [app_date] [source] [status]

set -e

# Function to execute SQL
exec_sql() {
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "$1"
}

# Function to get position ID
get_position_id() {
    local company_name="$1"
    local job_title="$2"
    exec_sql "
    SELECT jp.id 
    FROM hirewire.job_positions jp 
    JOIN hirewire.companies c ON jp.company_id = c.id 
    WHERE c.name = '$company_name' AND jp.title = '$job_title';
    " | grep -o '[0-9]\+' | head -1
}

if [ $# -eq 0 ]; then
    # Mode interactif
    echo "📝 Ajouter un processus d'entretien"
    echo "==================================="
    
    # List available positions
    echo "Postes disponibles:"
    exec_sql "
    SELECT c.name || ' - ' || jp.title 
    FROM hirewire.job_positions jp 
    JOIN hirewire.companies c ON jp.company_id = c.id 
    ORDER BY c.name, jp.title;
    " | grep -v '^$' | sed 's/^[[:space:]]*/- /'
    echo ""
    
    read -p "Nom de l'entreprise: " company_name
    read -p "Titre du poste: " job_title
    read -p "Date de candidature [$(date +%Y-%m-%d)]: " app_date
    app_date=${app_date:-$(date +%Y-%m-%d)}
    
    echo "Sources disponibles: linkedin, indeed, company_website, referral_internal, referral_external, networking"
    read -p "Source [linkedin]: " source
    source=${source:-linkedin}
    
    echo "Statuts: applied, screening, interviewing, final_round, offer, rejected, accepted, withdrew, ghosted, on_hold"
    read -p "Statut actuel [applied]: " status
    status=${status:-applied}
    
    read -p "Notes (optionnel): " notes
else
    # Mode commande
    company_name="$1"
    job_title="$2"
    app_date="${3:-$(date +%Y-%m-%d)}"
    source="${4:-linkedin}"
    status="${5:-applied}"
    notes="$6"
fi

if [[ -z "$company_name" || -z "$job_title" ]]; then
    echo "❌ Le nom de l'entreprise et le titre du poste sont obligatoires"
    exit 1
fi

# Get position ID
position_id=$(get_position_id "$company_name" "$job_title")
if [[ -z "$position_id" ]]; then
    echo "❌ Poste '$job_title' chez '$company_name' non trouvé"
    echo "💡 Ajoutez-le d'abord avec: ./scripts/add_job_position.sh '$company_name' '$job_title'"
    exit 1
fi

# Insert interview process
if [[ -n "$notes" ]]; then
    sql="INSERT INTO hirewire.interview_processes (job_position_id, application_date, source, status, notes) VALUES ($position_id, '$app_date', '$source', '$status', '$notes') RETURNING id;"
else
    sql="INSERT INTO hirewire.interview_processes (job_position_id, application_date, source, status) VALUES ($position_id, '$app_date', '$source', '$status') RETURNING id;"
fi

result=$(exec_sql "$sql")
process_id=$(echo "$result" | grep -o '[0-9]\+' | head -1)

echo "✅ Processus d'entretien ajouté (ID: $process_id)"
echo "   Entreprise: $company_name"
echo "   Poste: $job_title"
echo "   Date: $app_date"
echo "   Source: $source"
echo "   Statut: $status"

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage en ligne de commande:"
    echo "./scripts/add_process.sh 'TechCorp' 'Senior Developer' '2024-01-15' 'linkedin' 'interviewing'"
fi