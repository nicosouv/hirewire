#!/bin/bash
# Interface simple pour ajouter un entretien complet
# Usage: ./scripts/add_interview.sh

set -e

echo "🎯 Ajouter un entretien - Interface simple"
echo "========================================"

# Function to execute SQL
exec_sql() {
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "$1"
}

# Company
echo ""
echo "📊 Entreprise"
read -p "Nom de l'entreprise: " company_name
read -p "Secteur [Technology]: " industry
industry=${industry:-Technology}
read -p "Taille [100-500]: " size  
size=${size:-100-500}
read -p "Localisation [Paris, France]: " location
location=${location:-"Paris, France"}

# Insert company
exec_sql "
INSERT INTO hirewire.companies (name, industry, size, location) 
VALUES ('$company_name', '$industry', '$size', '$location') 
ON CONFLICT (name) DO UPDATE SET 
    industry = EXCLUDED.industry,
    size = EXCLUDED.size,
    location = EXCLUDED.location
RETURNING id;
" > /tmp/company_id.txt

company_id=$(grep -o '[0-9]\+' /tmp/company_id.txt | head -1)
echo "✅ Entreprise ajoutée (ID: $company_id)"

# Job position  
echo ""
echo "💼 Poste"
read -p "Titre du poste: " job_title
read -p "Département [Engineering]: " department
department=${department:-Engineering}
read -p "Level [senior]: " level
level=${level:-senior}
read -p "Salaire min (€): " salary_min
read -p "Salaire max (€): " salary_max

# Insert job position
exec_sql "
INSERT INTO hirewire.job_positions (company_id, title, department, level, salary_min, salary_max)
VALUES ($company_id, '$job_title', '$department', '$level', $salary_min, $salary_max)
RETURNING id;
" > /tmp/position_id.txt

position_id=$(grep -o '[0-9]\+' /tmp/position_id.txt | head -1)
echo "✅ Poste ajouté (ID: $position_id)"

# Interview process
echo ""
echo "📝 Candidature"
read -p "Date de candidature [$(date +%Y-%m-%d)]: " app_date
app_date=${app_date:-$(date +%Y-%m-%d)}
read -p "Source [linkedin]: " source
source=${source:-linkedin}
read -p "Statut actuel [applied]: " status
status=${status:-applied}

# Insert interview process
exec_sql "
INSERT INTO hirewire.interview_processes (job_position_id, application_date, source, status)
VALUES ($position_id, '$app_date', '$source', '$status')
RETURNING id;
" > /tmp/process_id.txt

process_id=$(grep -o '[0-9]\+' /tmp/process_id.txt | head -1)
echo "✅ Candidature ajoutée (ID: $process_id)"

# Interviews
echo ""
echo "🎤 Entretiens (appuyez sur Entrée pour terminer)"
round=1

while true; do
    echo ""
    echo "--- Entretien $round ---"
    read -p "Type d'entretien (phone/video/technical/behavioral): " interview_type
    
    if [[ -z "$interview_type" ]]; then
        break
    fi
    
    read -p "Date et heure (YYYY-MM-DD HH:MM): " interview_date
    read -p "Durée en minutes: " duration
    read -p "Nom de l'intervieweur: " interviewer_name
    read -p "Rôle de l'intervieweur: " interviewer_role
    read -p "Votre note (1-5): " rating
    
    # Insert interview
    exec_sql "
    INSERT INTO hirewire.interviews 
    (process_id, interview_type, interview_round, scheduled_date, actual_date, 
     duration_minutes, interviewer_name, interviewer_role, status, rating)
    VALUES ($process_id, '$interview_type', $round, '$interview_date', '$interview_date',
            $duration, '$interviewer_name', '$interviewer_role', 'completed', $rating);
    "
    
    echo "✅ Entretien $round ajouté"
    round=$((round + 1))
done

# Final outcome
echo ""
echo "📊 Résultat final (optionnel)"
read -p "Résultat (offer/rejection/ghosted/withdrew): " outcome

if [[ -n "$outcome" ]]; then
    read -p "Date du résultat [$(date +%Y-%m-%d)]: " outcome_date
    outcome_date=${outcome_date:-$(date +%Y-%m-%d)}
    
    if [[ "$outcome" == "offer" ]]; then
        read -p "Montant de l'offre (€): " offer_salary
        exec_sql "
        INSERT INTO hirewire.interview_outcomes 
        (process_id, outcome, outcome_date, offer_salary, overall_experience_rating)
        VALUES ($process_id, '$outcome', '$outcome_date', $offer_salary, 4);
        "
    else
        read -p "Raison du refus: " rejection_reason  
        read -p "Note globale de l'expérience (1-5): " overall_rating
        exec_sql "
        INSERT INTO hirewire.interview_outcomes 
        (process_id, outcome, outcome_date, rejection_reason, overall_experience_rating)
        VALUES ($process_id, '$outcome', '$outcome_date', '$rejection_reason', $overall_rating);
        "
    fi
    
    echo "✅ Résultat ajouté"
fi

echo ""
echo "🎉 Entretien ajouté avec succès!"
echo "💡 Lancez: ./scripts/etl_runner.sh pour mettre à jour les analytics"

# Cleanup
rm -f /tmp/company_id.txt /tmp/position_id.txt /tmp/process_id.txt