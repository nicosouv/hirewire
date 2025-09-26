#!/bin/bash

# Export CSV pour France Travail - Récapitulatif recherche d'emploi
# Génère un rapport complet des candidatures avec statistiques

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Fonction de log
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERREUR] $1${NC}" >&2
}

success() {
    echo -e "${GREEN}[SUCCÈS] $1${NC}"
}

# Vérifier si PostgreSQL est démarré
if ! docker-compose ps postgres | grep -q "Up"; then
    error "Le conteneur PostgreSQL n'est pas démarré. Utilisez: docker-compose up -d postgres"
    exit 1
fi

# Paramètres
LANGUAGE=${1:-"fr"}  # fr ou en
OUTPUT_DIR="exports/france_travail"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# Créer le dossier d'export
mkdir -p "$OUTPUT_DIR"

if [ "$LANGUAGE" = "fr" ]; then
    FILENAME="$OUTPUT_DIR/rapport_recherche_emploi_${TIMESTAMP}.csv"
    log "Génération du rapport France Travail en français..."
else
    FILENAME="$OUTPUT_DIR/job_search_report_${TIMESTAMP}.csv"
    log "Generating France Travail report in English..."
fi

# Génération du rapport CSV principal
log "Export des candidatures détaillées..."

if [ "$LANGUAGE" = "fr" ]; then
    # Version française
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "
    COPY (
        SELECT
            c.name as \"Entreprise\",
            jp.title as \"Poste\",
            c.location as \"Localisation\",
            jp.employment_type as \"Type_Contrat\",
            ip.application_date as \"Date_Candidature\",
            ip.status as \"Statut_Actuel\",
            ip.source as \"Source_Offre\",
            CURRENT_DATE - ip.application_date as \"Jours_Depuis_Candidature\",
            COALESCE(interview_stats.nb_entretiens, 0) as \"Nombre_Entretiens\",
            interview_stats.dernier_entretien as \"Date_Dernier_Entretien\",
            CASE
                WHEN interview_stats.dernier_entretien IS NOT NULL
                THEN CURRENT_DATE - interview_stats.dernier_entretien::DATE
                ELSE NULL
            END as \"Jours_Depuis_Dernier_Entretien\",
            io.outcome as \"Resultat_Final\",
            io.outcome_date as \"Date_Resultat\",
            CASE
                WHEN ip.status IN ('applied', 'screening', 'interviewing') AND io.outcome IS NULL
                THEN 'En cours'
                WHEN io.outcome = 'rejected' THEN 'Refusé'
                WHEN io.outcome = 'ghosted' THEN 'Sans réponse'
                WHEN io.outcome = 'accepted' THEN 'Accepté'
                WHEN io.outcome = 'offer' THEN 'Offre reçue'
                WHEN ip.status = 'withdrew' THEN 'Retiré'
                ELSE 'Autre'
            END as \"Statut_Readable\",
            CASE
                WHEN ip.status IN ('applied', 'screening', 'interviewing') AND
                     (CURRENT_DATE - ip.application_date) > 30 AND io.outcome IS NULL
                THEN 'Délai dépassé (>30j)'
                WHEN ip.status IN ('applied', 'screening', 'interviewing') AND io.outcome IS NULL
                THEN 'En attente normale'
                ELSE 'Traité'
            END as \"Evaluation_Delai\"
        FROM hirewire.interview_processes ip
        JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
        LEFT JOIN (
            SELECT
                process_id,
                COUNT(*) as nb_entretiens,
                MAX(scheduled_date) as dernier_entretien
            FROM hirewire.interviews
            GROUP BY process_id
        ) interview_stats ON ip.id = interview_stats.process_id
        ORDER BY ip.application_date DESC
    ) TO STDOUT WITH CSV HEADER;
    " > "$FILENAME"
else
    # Version anglaise
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "
    COPY (
        SELECT
            c.name as \"Company\",
            jp.title as \"Position\",
            c.location as \"Location\",
            jp.employment_type as \"Contract_Type\",
            ip.application_date as \"Application_Date\",
            ip.status as \"Current_Status\",
            ip.source as \"Job_Source\",
            CURRENT_DATE - ip.application_date as \"Days_Since_Application\",
            COALESCE(interview_stats.nb_entretiens, 0) as \"Number_Interviews\",
            interview_stats.dernier_entretien as \"Last_Interview_Date\",
            CASE
                WHEN interview_stats.dernier_entretien IS NOT NULL
                THEN CURRENT_DATE - interview_stats.dernier_entretien::DATE
                ELSE NULL
            END as \"Days_Since_Last_Interview\",
            io.outcome as \"Final_Outcome\",
            io.outcome_date as \"Outcome_Date\",
            CASE
                WHEN ip.status IN ('applied', 'screening', 'interviewing') AND io.outcome IS NULL
                THEN 'In Progress'
                WHEN io.outcome = 'rejected' THEN 'Rejected'
                WHEN io.outcome = 'ghosted' THEN 'No Response'
                WHEN io.outcome = 'accepted' THEN 'Accepted'
                WHEN io.outcome = 'offer' THEN 'Offer Received'
                WHEN ip.status = 'withdrew' THEN 'Withdrew'
                ELSE 'Other'
            END as \"Status_Readable\",
            CASE
                WHEN ip.status IN ('applied', 'screening', 'interviewing') AND
                     (CURRENT_DATE - ip.application_date) > 30 AND io.outcome IS NULL
                THEN 'Overdue (>30d)'
                WHEN ip.status IN ('applied', 'screening', 'interviewing') AND io.outcome IS NULL
                THEN 'Normal waiting'
                ELSE 'Processed'
            END as \"Delay_Assessment\"
        FROM hirewire.interview_processes ip
        JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
        LEFT JOIN (
            SELECT
                process_id,
                COUNT(*) as nb_entretiens,
                MAX(scheduled_date) as dernier_entretien
            FROM hirewire.interviews
            GROUP BY process_id
        ) interview_stats ON ip.id = interview_stats.process_id
        ORDER BY ip.application_date DESC
    ) TO STDOUT WITH CSV HEADER;
    " > "$FILENAME"
fi

success "Rapport détaillé exporté: $FILENAME"

# Génération du fichier de statistiques
if [ "$LANGUAGE" = "fr" ]; then
    STATS_FILE="$OUTPUT_DIR/statistiques_recherche_${TIMESTAMP}.csv"
    log "Génération des statistiques générales..."
else
    STATS_FILE="$OUTPUT_DIR/job_search_statistics_${TIMESTAMP}.csv"
    log "Generating general statistics..."
fi

if [ "$LANGUAGE" = "fr" ]; then
    # Statistiques en français
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "
    COPY (
        SELECT
            'Statistiques Générales' as \"Catégorie\",
            'Total candidatures' as \"Métrique\",
            COUNT(*)::text as \"Valeur\",
            'Nombre total de candidatures envoyées' as \"Description\"
        FROM hirewire.interview_processes

        UNION ALL

        SELECT
            'Statistiques Générales',
            'Candidatures actives',
            COUNT(*)::text,
            'Candidatures en cours sans résultat final'
        FROM hirewire.interview_processes ip
        WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)

        UNION ALL

        SELECT
            'Statistiques Générales',
            'Total entretiens',
            COUNT(*)::text,
            'Nombre total d''entretiens obtenus'
        FROM hirewire.interviews

        UNION ALL

        SELECT
            'Statistiques Générales',
            'Taux de conversion entretien',
            ROUND((COUNT(DISTINCT i.process_id)::decimal / COUNT(DISTINCT ip.id)) * 100, 1)::text || '%',
            'Pourcentage de candidatures ayant mené à un entretien'
        FROM hirewire.interview_processes ip
        LEFT JOIN hirewire.interviews i ON ip.id = i.process_id

        UNION ALL

        SELECT
            'Délais de Réponse',
            'Délai moyen de réponse',
            ROUND(AVG(CURRENT_DATE - ip.application_date))::text || ' jours',
            'Délai moyen entre candidature et première réponse/entretien'
        FROM hirewire.interview_processes ip
        JOIN hirewire.interviews i ON ip.id = i.process_id

        UNION ALL

        SELECT
            'Délais de Réponse',
            'Candidatures en attente >30j',
            COUNT(*)::text,
            'Nombre de candidatures sans réponse depuis plus de 30 jours'
        FROM hirewire.interview_processes ip
        WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
        AND (CURRENT_DATE - ip.application_date) > 30

        UNION ALL

        SELECT
            'Résultats',
            'Offres reçues',
            COUNT(*)::text,
            'Nombre d''offres d''emploi reçues'
        FROM hirewire.interview_outcomes
        WHERE outcome IN ('offer', 'accepted')

        UNION ALL

        SELECT
            'Résultats',
            'Processus ghostés',
            COUNT(*)::text,
            'Entreprises n''ayant jamais répondu'
        FROM hirewire.interview_outcomes
        WHERE outcome = 'ghosted'

        UNION ALL

        SELECT
            'Activité Récente',
            'Candidatures ce mois',
            COUNT(*)::text,
            'Candidatures envoyées dans les 30 derniers jours'
        FROM hirewire.interview_processes
        WHERE application_date >= CURRENT_DATE - INTERVAL '30 days'

        UNION ALL

        SELECT
            'Activité Récente',
            'Entretiens ce mois',
            COUNT(*)::text,
            'Entretiens programmés dans les 30 derniers jours'
        FROM hirewire.interviews
        WHERE scheduled_date >= CURRENT_DATE - INTERVAL '30 days'
    ) TO STDOUT WITH CSV HEADER;
    " > "$STATS_FILE"
else
    # Statistiques en anglais
    docker-compose exec -T postgres psql -U postgres -d hirewire -c "
    COPY (
        SELECT
            'General Statistics' as \"Category\",
            'Total applications' as \"Metric\",
            COUNT(*)::text as \"Value\",
            'Total number of job applications sent' as \"Description\"
        FROM hirewire.interview_processes

        UNION ALL

        SELECT
            'General Statistics',
            'Active applications',
            COUNT(*)::text,
            'Applications in progress without final outcome'
        FROM hirewire.interview_processes ip
        WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)

        UNION ALL

        SELECT
            'General Statistics',
            'Total interviews',
            COUNT(*)::text,
            'Total number of interviews obtained'
        FROM hirewire.interviews

        UNION ALL

        SELECT
            'General Statistics',
            'Interview conversion rate',
            ROUND((COUNT(DISTINCT i.process_id)::decimal / COUNT(DISTINCT ip.id)) * 100, 1)::text || '%',
            'Percentage of applications that led to an interview'
        FROM hirewire.interview_processes ip
        LEFT JOIN hirewire.interviews i ON ip.id = i.process_id

        UNION ALL

        SELECT
            'Response Times',
            'Average response time',
            ROUND(AVG(CURRENT_DATE - ip.application_date))::text || ' days',
            'Average time between application and first response/interview'
        FROM hirewire.interview_processes ip
        JOIN hirewire.interviews i ON ip.id = i.process_id

        UNION ALL

        SELECT
            'Response Times',
            'Applications waiting >30d',
            COUNT(*)::text,
            'Applications without response for more than 30 days'
        FROM hirewire.interview_processes ip
        WHERE ip.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
        AND (CURRENT_DATE - ip.application_date) > 30

        UNION ALL

        SELECT
            'Results',
            'Job offers received',
            COUNT(*)::text,
            'Number of job offers received'
        FROM hirewire.interview_outcomes
        WHERE outcome IN ('offer', 'accepted')

        UNION ALL

        SELECT
            'Results',
            'Ghosted processes',
            COUNT(*)::text,
            'Companies that never responded'
        FROM hirewire.interview_outcomes
        WHERE outcome = 'ghosted'

        UNION ALL

        SELECT
            'Recent Activity',
            'Applications this month',
            COUNT(*)::text,
            'Applications sent in the last 30 days'
        FROM hirewire.interview_processes
        WHERE application_date >= CURRENT_DATE - INTERVAL '30 days'

        UNION ALL

        SELECT
            'Recent Activity',
            'Interviews this month',
            COUNT(*)::text,
            'Interviews scheduled in the last 30 days'
        FROM hirewire.interviews
        WHERE scheduled_date >= CURRENT_DATE - INTERVAL '30 days'
    ) TO STDOUT WITH CSV HEADER;
    " > "$STATS_FILE"
fi

success "Statistiques exportées: $STATS_FILE"

# Génération d'un rapport résumé pour France Travail
if [ "$LANGUAGE" = "fr" ]; then
    SUMMARY_FILE="$OUTPUT_DIR/resume_france_travail_${TIMESTAMP}.txt"
    log "Génération du résumé France Travail..."

    echo "RAPPORT DE RECHERCHE D'EMPLOI - $(date '+%d/%m/%Y')" > "$SUMMARY_FILE"
    echo "=================================================" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"

    # Statistiques principales
    docker-compose exec -T postgres psql -U postgres -d hirewire -t -c "
    SELECT
        'ACTIVITÉ DE RECHERCHE D''EMPLOI:' || chr(10) ||
        '• Total candidatures envoyées: ' || COUNT(*) || chr(10) ||
        '• Période: du ' || MIN(application_date) || ' au ' || MAX(application_date) || chr(10) ||
        '• Candidatures actives: ' || (
            SELECT COUNT(*) FROM hirewire.interview_processes ip2
            WHERE ip2.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
        ) || chr(10) ||
        '• Entretiens obtenus: ' || (SELECT COUNT(*) FROM hirewire.interviews) || chr(10) ||
        chr(10) ||
        'DÉLAIS DE RÉPONSE DES ENTREPRISES:' || chr(10) ||
        '• Entreprises ayant répondu rapidement (<15j): ' || (
            SELECT COUNT(*) FROM hirewire.interview_processes ip3
            JOIN hirewire.interviews i ON ip3.id = i.process_id
            WHERE (i.scheduled_date::DATE - ip3.application_date) <= 15
        ) || chr(10) ||
        '• Candidatures en attente depuis >30 jours: ' || (
            SELECT COUNT(*) FROM hirewire.interview_processes ip4
            WHERE ip4.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
            AND (CURRENT_DATE - ip4.application_date) > 30
        ) || chr(10) ||
        '• Entreprises sans réponse (ghosting): ' || (
            SELECT COUNT(*) FROM hirewire.interview_outcomes WHERE outcome = 'ghosted'
        ) || chr(10) ||
        chr(10) ||
        'RÉSULTATS:' || chr(10) ||
        '• Offres d''emploi reçues: ' || (
            SELECT COUNT(*) FROM hirewire.interview_outcomes WHERE outcome IN ('offer', 'accepted')
        ) || chr(10) ||
        '• Taux de conversion entretien: ' || ROUND((
            (SELECT COUNT(DISTINCT i.process_id) FROM hirewire.interviews i)::decimal / COUNT(*)
        ) * 100, 1) || '%' || chr(10) ||
        chr(10) ||
        'Ce rapport démontre une recherche d''emploi active et méthodique.'
    FROM hirewire.interview_processes;
    " >> "$SUMMARY_FILE"
else
    SUMMARY_FILE="$OUTPUT_DIR/france_travail_summary_${TIMESTAMP}.txt"
    log "Generating France Travail summary..."

    echo "JOB SEARCH REPORT - $(date '+%m/%d/%Y')" > "$SUMMARY_FILE"
    echo "=======================================" >> "$SUMMARY_FILE"
    echo "" >> "$SUMMARY_FILE"

    # Main statistics
    docker-compose exec -T postgres psql -U postgres -d hirewire -t -c "
    SELECT
        'JOB SEARCH ACTIVITY:' || chr(10) ||
        '• Total applications sent: ' || COUNT(*) || chr(10) ||
        '• Period: from ' || MIN(application_date) || ' to ' || MAX(application_date) || chr(10) ||
        '• Active applications: ' || (
            SELECT COUNT(*) FROM hirewire.interview_processes ip2
            WHERE ip2.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
        ) || chr(10) ||
        '• Interviews obtained: ' || (SELECT COUNT(*) FROM hirewire.interviews) || chr(10) ||
        chr(10) ||
        'COMPANY RESPONSE TIMES:' || chr(10) ||
        '• Companies with quick response (<15d): ' || (
            SELECT COUNT(*) FROM hirewire.interview_processes ip3
            JOIN hirewire.interviews i ON ip3.id = i.process_id
            WHERE (i.scheduled_date::DATE - ip3.application_date) <= 15
        ) || chr(10) ||
        '• Applications waiting >30 days: ' || (
            SELECT COUNT(*) FROM hirewire.interview_processes ip4
            WHERE ip4.id NOT IN (SELECT DISTINCT process_id FROM hirewire.interview_outcomes WHERE process_id IS NOT NULL)
            AND (CURRENT_DATE - ip4.application_date) > 30
        ) || chr(10) ||
        '• Companies with no response (ghosting): ' || (
            SELECT COUNT(*) FROM hirewire.interview_outcomes WHERE outcome = 'ghosted'
        ) || chr(10) ||
        chr(10) ||
        'RESULTS:' || chr(10) ||
        '• Job offers received: ' || (
            SELECT COUNT(*) FROM hirewire.interview_outcomes WHERE outcome IN ('offer', 'accepted')
        ) || chr(10) ||
        '• Interview conversion rate: ' || ROUND((
            (SELECT COUNT(DISTINCT i.process_id) FROM hirewire.interviews i)::decimal / COUNT(*)
        ) * 100, 1) || '%' || chr(10) ||
        chr(10) ||
        'This report demonstrates active and methodical job searching.'
    FROM hirewire.interview_processes;
    " >> "$SUMMARY_FILE"
fi

success "Résumé exporté: $SUMMARY_FILE"

if [ "$LANGUAGE" = "fr" ]; then
    echo ""
    echo "=== FICHIERS GÉNÉRÉS ==="
    echo "📊 Rapport détaillé:  $FILENAME"
    echo "📈 Statistiques:      $STATS_FILE"
    echo "📋 Résumé exécutif:   $SUMMARY_FILE"
    echo ""
    echo "Ces fichiers peuvent être directement transmis à France Travail"
    echo "pour justifier de votre recherche d'emploi active."
else
    echo ""
    echo "=== GENERATED FILES ==="
    echo "📊 Detailed report:   $FILENAME"
    echo "📈 Statistics:        $STATS_FILE"
    echo "📋 Executive summary: $SUMMARY_FILE"
    echo ""
    echo "These files can be directly submitted to France Travail"
    echo "to justify your active job search."
fi

log "Export terminé avec succès!"