#!/bin/bash
# Ajouter un processus d'entretien
# Usage: ./scripts/add_process.sh [position_id] [app_date] [source] [status]

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
    SELECT jp.id || ': ' || c.name || ' - ' || jp.title 
    FROM hirewire.job_positions jp 
    JOIN hirewire.companies c ON jp.company_id = c.id 
    ORDER BY c.name, jp.title;
    " | grep -v '^$' | sed 's/^[[:space:]]*/- /'
    echo ""
    
    read -p "ID du poste: " position_id
    read -p "Date de candidature [$(date +%Y-%m-%d)]: " app_date
    app_date=${app_date:-$(date +%Y-%m-%d)}
    
    echo "Sources disponibles: linkedin, indeed, company_website, referral_internal, referral_external, networking"
    read -p "Source [linkedin]: " source
    source=${source:-linkedin}
    
    echo "Statuts: applied, tech test, reminder, screening, interviewing, final_round, offer, rejected, accepted, withdrew, ghosted, on_hold"
    read -p "Statut actuel [applied]: " status
    status=${status:-applied}
    
    read -p "Notes (optionnel): " notes
else
    # Mode commande
    position_id="$1"
    app_date="${2:-$(date +%Y-%m-%d)}"
    source="${3:-linkedin}"
    status="${4:-applied}"
    notes="$5"
fi

if [[ -z "$position_id" ]]; then
    echo "❌ L'ID du poste est obligatoire"
    exit 1
fi

# Verify position exists and get company/job info
position_info=$(exec_sql "
    SELECT c.name || ' - ' || jp.title
    FROM hirewire.job_positions jp 
    JOIN hirewire.companies c ON jp.company_id = c.id 
    WHERE jp.id = $position_id;
" | grep -v '^$' | head -1 | xargs)
if [[ -z "$position_info" ]]; then
    echo "❌ Poste avec l'ID $position_id non trouvé"
    echo "💡 Vérifiez l'ID ou ajoutez le poste avec: ./scripts/add_job_position.sh"
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
echo "   Poste: $position_info"
echo "   Date: $app_date"
echo "   Source: $source"
echo "   Statut: $status"

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage en ligne de commande:"
    echo "./scripts/add_process.sh 1 '2024-01-15' 'linkedin' 'interviewing'"
fi