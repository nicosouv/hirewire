#!/bin/bash
# Ajouter un entretien individuel
# Usage: ./scripts/add_single_interview.sh [process_id] [type] [date] [duration] [interviewer] [rating]

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
    echo "🎤 Ajouter un entretien"
    echo "======================"
    
    # List processes
    echo "Processus disponibles:"
    exec_sql "
    SELECT ip.id || ': ' || c.name || ' - ' || jp.title || ' (' || ip.status || ')'
    FROM hirewire.interview_processes ip
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    ORDER BY ip.id DESC
    LIMIT 10;
    " | grep -v '^$' | sed 's/^[[:space:]]*/- /'
    echo ""
    
    read -p "ID du processus: " process_id
    
    echo "Types: phone_screening, video_screening, technical_phone, technical_video, coding_challenge, system_design, behavioral, cultural_fit, final_round, on_site, presentation, pair_programming, take_home"
    read -p "Type d'entretien: " interview_type
    read -p "Round [1]: " round
    round=${round:-1}
    read -p "Date et heure (YYYY-MM-DD HH:MM): " scheduled_date
    read -p "Durée en minutes: " duration
    read -p "Nom de l'intervieweur: " interviewer_name
    read -p "Rôle de l'intervieweur: " interviewer_role
    
    echo "Statuts: scheduled, completed, cancelled, no-show"
    read -p "Statut [completed]: " status
    status=${status:-completed}
    
    read -p "Votre note (1-5): " rating
    read -p "Feedback (optionnel): " feedback
    read -p "Sujets techniques (séparés par des virgules): " topics
else
    # Mode commande
    process_id="$1"
    interview_type="$2"
    scheduled_date="$3"
    duration="$4"
    interviewer_name="$5"
    rating="$6"
    round="${7:-1}"
    interviewer_role="$8"
    status="${9:-completed}"
    feedback="${10}"
fi

if [[ -z "$process_id" || -z "$interview_type" ]]; then
    echo "❌ L'ID du processus et le type d'entretien sont obligatoires"
    exit 1
fi

# Verify process exists
process_info=$(get_process_info "$process_id")
if [[ -z "$process_info" ]]; then
    echo "❌ Processus #$process_id non trouvé"
    exit 1
fi

# Build SQL
sql="INSERT INTO hirewire.interviews (process_id, interview_type, interview_round"
values="VALUES ($process_id, '$interview_type', $round"

if [[ -n "$scheduled_date" ]]; then
    sql="$sql, scheduled_date, actual_date"
    values="$values, '$scheduled_date', '$scheduled_date'"
fi

if [[ -n "$duration" ]]; then
    sql="$sql, duration_minutes"
    values="$values, $duration"
fi

if [[ -n "$interviewer_name" ]]; then
    sql="$sql, interviewer_name"
    values="$values, '$interviewer_name'"
fi

if [[ -n "$interviewer_role" ]]; then
    sql="$sql, interviewer_role"
    values="$values, '$interviewer_role'"
fi

if [[ -n "$status" ]]; then
    sql="$sql, status"
    values="$values, '$status'"
fi

if [[ -n "$rating" ]]; then
    sql="$sql, rating"
    values="$values, $rating"
fi

if [[ -n "$feedback" ]]; then
    sql="$sql, feedback"
    values="$values, '$feedback'"
fi

if [[ -n "$topics" ]]; then
    # Convert comma-separated topics to PostgreSQL array
    topics_array="{$(echo "$topics" | sed 's/, */","/g' | sed 's/^/"/' | sed 's/$/"/')}"
    sql="$sql, technical_topics"
    values="$values, '$topics_array'"
fi

sql="$sql) $values) RETURNING id;"

# Insert interview
result=$(exec_sql "$sql")
interview_id=$(echo "$result" | grep -o '[0-9]\+' | head -1)

echo "✅ Entretien ajouté (ID: $interview_id)"
echo "   Processus: $process_info"
echo "   Type: $interview_type"
echo "   Round: $round"
if [[ -n "$scheduled_date" ]]; then echo "   Date: $scheduled_date"; fi
if [[ -n "$duration" ]]; then echo "   Durée: $duration min"; fi
if [[ -n "$rating" ]]; then echo "   Note: $rating/5"; fi

# Show usage examples
if [ $# -eq 0 ]; then
    echo ""
    echo "💡 Usage en ligne de commande:"
    echo "./scripts/add_single_interview.sh 1 'technical_video' '2024-01-20 14:00' 90 'John Doe' 4"
fi