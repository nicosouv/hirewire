#!/bin/bash
# Ajouter un résultat d'entretien
# Usage: ./scripts/add_outcome.sh [process_id] [outcome] [outcome_date] [offer_salary] [rejection_reason] [rating]

set -e

# Function to execute SQL
exec_sql() {
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "$1"
}

# Function to get process info
get_process_info() {
    local process_id="$1"
    exec_sql "
    SELECT c.name || ' - ' || jp.title || ' (Process #' || ip.id || ')'
    FROM hirewire.interview_processes ip
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    WHERE ip.id = $process_id;
    " | grep -v '^$' | head -1
}

if [ $# -eq 0 ]; then
    # Mode interactif
    echo "📊 Ajouter un résultat d'entretien"
    echo "=================================="
    
    # List processes without outcomes
    echo "Processus sans résultat:"
    exec_sql "
    SELECT ip.id || ': ' || c.name || ' - ' || jp.title || ' (' || ip.status || ')'
    FROM hirewire.interview_processes ip
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
    WHERE io.id IS NULL
    ORDER BY ip.id DESC;
    " | grep -v '^$' | sed 's/^[[:space:]]*/- /'
    echo ""
    
    read -p "ID du processus: " process_id
    
    echo "Résultats possibles: offer, rejection, ghosted, withdrew"
    read -p "Résultat: " outcome
    read -p "Date du résultat [$(date +%Y-%m-%d)]: " outcome_date
    outcome_date=${outcome_date:-$(date +%Y-%m-%d)}
    
    if [[ "$outcome" == "offer" ]]; then
        read -p "Montant de l'offre (€): " offer_salary
        read -p "Devise [EUR]: " offer_currency
        offer_currency=${offer_currency:-EUR}
    elif [[ "$outcome" == "rejection" ]]; then
        read -p "Raison du refus (optionnel): " rejection_reason
    fi
    
    read -p "Feedback reçu (y/n) [n]: " feedback_received
    feedback_received=${feedback_received:-n}
    
    read -p "Candidateriez-vous à nouveau ? (y/n): " would_reapply
    
    read -p "Note globale de l'expérience (1-5): " overall_rating
    read -p "Notes supplémentaires (optionnel): " notes
else
    # Mode commande
    process_id="$1"
    outcome="$2"
    outcome_date="${3:-$(date +%Y-%m-%d)}"
    offer_salary="$4"
    rejection_reason="$5"
    overall_rating="$6"
    offer_currency="${7:-EUR}"
    feedback_received="${8:-n}"
    would_reapply="$9"
    notes="${10}"
fi

if [[ -z "$process_id" || -z "$outcome" ]]; then
    echo "❌ L'ID du processus et le résultat sont obligatoires"
    exit 1
fi

# Verify process exists
process_info=$(get_process_info "$process_id")
if [[ -z "$process_info" ]]; then
    echo "❌ Processus #$process_id non trouvé"
    exit 1
fi

# Convert y/n to boolean
if [[ "$feedback_received" == "y" ]]; then
    feedback_received="true"
else
    feedback_received="false"
fi

if [[ "$would_reapply" == "y" ]]; then
    would_reapply="true"
elif [[ "$would_reapply" == "n" ]]; then
    would_reapply="false"
else
    would_reapply="NULL"
fi

# Build SQL
sql="INSERT INTO hirewire.interview_outcomes (process_id, outcome, outcome_date, feedback_received"
values="VALUES ($process_id, '$outcome', '$outcome_date', $feedback_received"

if [[ -n "$offer_salary" && "$outcome" == "offer" ]]; then
    sql="$sql, offer_salary, offer_currency"
    values="$values, $offer_salary, '$offer_currency'"
fi

if [[ -n "$rejection_reason" && "$outcome" == "rejection" ]]; then
    sql="$sql, rejection_reason"
    values="$values, '$rejection_reason'"
fi

if [[ "$would_reapply" != "NULL" ]]; then
    sql="$sql, would_reapply"
    values="$values, $would_reapply"
fi

if [[ -n "$overall_rating" ]]; then
    sql="$sql, overall_experience_rating"
    values="$values, $overall_rating"
fi

if [[ -n "$notes" ]]; then
    sql="$sql, notes"
    values="$values, '$notes'"
fi

sql="$sql) $values) RETURNING id;"

# Insert outcome
result=$(exec_sql "$sql")
outcome_id=$(echo "$result" | grep -o '[0-9]\+' | head -1)

echo "✅ Résultat d'entretien ajouté (ID: $outcome_id)"
echo "   Processus: $process_info"
echo "   Résultat: $outcome"
echo "   Date: $outcome_date"
if [[ -n "$offer_salary" ]]; then echo "   Offre: $offer_salary $offer_currency"; fi
if [[ -n "$overall_rating" ]]; then echo "   Note globale: $overall_rating/5"; fi

# Update process status if needed
if [[ "$outcome" == "offer" ]]; then
    exec_sql "UPDATE hirewire.interview_processes SET status = 'offer' WHERE id = $process_id;" > /dev/null
    echo "   ↳ Statut du processus mis à jour: offer"
elif [[ "$outcome" == "rejection" ]]; then
    exec_sql "UPDATE hirewire.interview_processes SET status = 'rejected' WHERE id = $process_id;" > /dev/null
    echo "   ↳ Statut du processus mis à jour: rejected"
fi

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage en ligne de commande:"
    echo "./scripts/add_outcome.sh 1 'offer' '2024-01-25' 75000 '' 5"
    echo "./scripts/add_outcome.sh 2 'rejection' '2024-01-22' '' 'Not enough experience' 3"
fi