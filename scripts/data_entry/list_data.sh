#!/bin/bash
# Afficher les données existantes
# Usage: ./scripts/list_data.sh [table]

set -e

# Function to execute SQL
exec_sql() {
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "$1"
}

show_companies() {
    echo "📊 ENTREPRISES"
    echo "=============="
    exec_sql "
    SELECT id, name, industry, size, location 
    FROM hirewire.companies 
    ORDER BY name;
    " | head -20
}

show_positions() {
    echo "💼 POSTES"
    echo "========="
    exec_sql "
    SELECT jp.id, c.name as company, jp.title, jp.level, jp.salary_min, jp.salary_max
    FROM hirewire.job_positions jp
    JOIN hirewire.companies c ON jp.company_id = c.id
    ORDER BY c.name, jp.title;
    " | head -20
}

show_processes() {
    echo "📝 PROCESSUS D'ENTRETIEN"
    echo "======================="
    exec_sql "
    SELECT ip.id, c.name as company, jp.title, ip.application_date, ip.status, ip.source
    FROM hirewire.interview_processes ip
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    ORDER BY ip.application_date DESC;
    " | head -20
}

show_interviews() {
    echo "🎤 ENTRETIENS"
    echo "============"
    exec_sql "
    SELECT i.id, c.name as company, jp.title, i.interview_type, i.scheduled_date, i.rating
    FROM hirewire.interviews i
    JOIN hirewire.interview_processes ip ON i.process_id = ip.id
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    ORDER BY i.scheduled_date DESC;
    " | head -20
}

show_outcomes() {
    echo "📊 RÉSULTATS"
    echo "==========="
    exec_sql "
    SELECT io.id, c.name as company, jp.title, io.outcome, io.outcome_date, io.offer_salary, io.overall_experience_rating
    FROM hirewire.interview_outcomes io
    JOIN hirewire.interview_processes ip ON io.process_id = ip.id
    JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
    JOIN hirewire.companies c ON jp.company_id = c.id
    ORDER BY io.outcome_date DESC;
    " | head -20
}

show_stats() {
    echo "📈 STATISTIQUES"
    echo "==============="
    echo "Entreprises:"
    exec_sql "SELECT COUNT(*) FROM hirewire.companies;" | grep -o '[0-9]\+'
    
    echo "Postes:"
    exec_sql "SELECT COUNT(*) FROM hirewire.job_positions;" | grep -o '[0-9]\+'
    
    echo "Processus d'entretien:"
    exec_sql "SELECT COUNT(*) FROM hirewire.interview_processes;" | grep -o '[0-9]\+'
    
    echo "Entretiens individuels:"
    exec_sql "SELECT COUNT(*) FROM hirewire.interviews;" | grep -o '[0-9]\+'
    
    echo "Résultats:"
    exec_sql "SELECT COUNT(*) FROM hirewire.interview_outcomes;" | grep -o '[0-9]\+'
    
    echo ""
    echo "Par statut:"
    exec_sql "
    SELECT status, COUNT(*) 
    FROM hirewire.interview_processes 
    GROUP BY status 
    ORDER BY COUNT(*) DESC;
    "
    
    echo ""
    echo "Par résultat:"
    exec_sql "
    SELECT outcome, COUNT(*) 
    FROM hirewire.interview_outcomes 
    GROUP BY outcome 
    ORDER BY COUNT(*) DESC;
    "
}

case "${1:-all}" in
    "companies"|"c")
        show_companies
        ;;
    "positions"|"jobs"|"p")
        show_positions
        ;;
    "processes"|"proc")
        show_processes
        ;;
    "interviews"|"i")
        show_interviews
        ;;
    "outcomes"|"results"|"o")
        show_outcomes
        ;;
    "stats"|"s")
        show_stats
        ;;
    "all"|*)
        show_stats
        echo ""
        show_companies
        echo ""
        show_positions
        echo ""
        show_processes
        echo ""
        show_interviews
        echo ""
        show_outcomes
        ;;
esac

echo ""
echo "💡 Usage: ./scripts/list_data.sh [companies|positions|processes|interviews|outcomes|stats]"