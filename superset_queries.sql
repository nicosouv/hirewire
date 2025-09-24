-- SUPERSET DASHBOARD QUERIES
-- Pour mart_active_applications

-- ============================================
-- DASHBOARD 1: ACTION CENTER
-- ============================================

-- 1. ACTIONS URGENTES (Table)
SELECT
    company_name,
    job_title,
    next_action,
    suggested_follow_up_date,
    days_since_application,
    priority_score,
    current_status
FROM mart_active_applications
WHERE suggested_follow_up_date <= CURRENT_DATE + INTERVAL '3 days'
ORDER BY priority_score DESC, suggested_follow_up_date;

-- 2. RÉPARTITION DES ACTIONS (Pie Chart)
SELECT
    next_action,
    COUNT(*) as count
FROM mart_active_applications
GROUP BY next_action
ORDER BY count DESC;

-- 3. TIMELINE 7 JOURS (Bar Chart)
SELECT
    suggested_follow_up_date::DATE as date,
    COUNT(*) as nb_actions
FROM mart_active_applications
WHERE suggested_follow_up_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
GROUP BY suggested_follow_up_date::DATE
ORDER BY date;

-- 4. KPI CARDS
-- Total applications actives
SELECT COUNT(*) as total_active FROM mart_active_applications;

-- Actions en retard
SELECT COUNT(*) as overdue
FROM mart_active_applications
WHERE suggested_follow_up_date < CURRENT_DATE;

-- Actions cette semaine
SELECT COUNT(*) as this_week
FROM mart_active_applications
WHERE suggested_follow_up_date BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days';

-- ============================================
-- DASHBOARD 2: PIPELINE OVERVIEW
-- ============================================

-- 5. KANBAN DES STATUTS (Horizontal Bar)
SELECT
    status_category,
    COUNT(*) as nb_applications,
    AVG(days_since_application) as avg_days_waiting
FROM mart_active_applications
GROUP BY status_category
ORDER BY
    CASE status_category
        WHEN 'Waiting for Response' THEN 1
        WHEN 'In Screening' THEN 2
        WHEN 'In Interview Process' THEN 3
        WHEN 'Offer Stage' THEN 4
        ELSE 5
    END;

-- 6. DISTRIBUTION PAR TEMPS D'ATTENTE (Mixed Chart)
SELECT
    CASE
        WHEN days_since_application <= 7 THEN '≤ 1 semaine'
        WHEN days_since_application <= 14 THEN '1-2 semaines'
        WHEN days_since_application <= 30 THEN '2-4 semaines'
        ELSE '> 1 mois'
    END as waiting_period,
    COUNT(*) as nb_applications,
    AVG(priority_score) as avg_priority
FROM mart_active_applications
GROUP BY waiting_period
ORDER BY MIN(days_since_application);

-- 7. HEATMAP INDUSTRIE × NIVEAU (Heatmap)
SELECT
    COALESCE(industry, 'Non spécifié') as industry,
    COALESCE(level, 'Non spécifié') as level,
    COUNT(*) as nb_applications
FROM mart_active_applications
GROUP BY industry, level;

-- ============================================
-- DASHBOARD 3: PERFORMANCE ANALYSIS
-- ============================================

-- 8. EFFICACITÉ PAR SOURCE (Radar/Bar Chart)
SELECT
    source,
    COUNT(*) as total_applications,
    AVG(total_interviews) as avg_interviews_reached,
    COUNT(CASE WHEN current_status IN ('interviewing', 'screening', 'tech_test') THEN 1 END) as nb_progressed,
    ROUND(COUNT(CASE WHEN current_status IN ('interviewing', 'screening', 'tech_test') THEN 1 END) * 100.0 / COUNT(*), 1) as progression_rate
FROM mart_active_applications
GROUP BY source
ORDER BY progression_rate DESC;

-- 9. ANALYSE SALARIALE (Bar Chart with dual axis)
SELECT
    CASE
        WHEN salary_min < 50000 THEN '<50k'
        WHEN salary_min < 70000 THEN '50-70k'
        WHEN salary_min < 90000 THEN '70-90k'
        ELSE '90k+'
    END as salary_range,
    COUNT(*) as nb_opportunities,
    AVG(days_since_application) as avg_days_pending,
    AVG(priority_score) as avg_priority
FROM mart_active_applications
WHERE salary_min IS NOT NULL
GROUP BY salary_range
ORDER BY MIN(salary_min);

-- 10. TOP COMPANIES BY ACTIVITY (Table)
SELECT
    company_name,
    COUNT(*) as nb_active_processes,
    AVG(priority_score) as avg_priority,
    MAX(days_since_application) as oldest_application,
    STRING_AGG(DISTINCT current_status, ', ') as statuses
FROM mart_active_applications
GROUP BY company_name
HAVING COUNT(*) > 1
ORDER BY nb_active_processes DESC, avg_priority DESC;

-- ============================================
-- MÉTRIQUES CALCULÉES UTILES
-- ============================================

-- Taux de progression global
SELECT
    ROUND(COUNT(CASE WHEN current_status NOT IN ('applied') THEN 1 END) * 100.0 / COUNT(*), 1) as progression_rate
FROM mart_active_applications;

-- Délai moyen avant premier entretien
SELECT
    AVG(CASE WHEN total_interviews > 0 THEN days_since_application END) as avg_days_to_interview
FROM mart_active_applications;

-- Score priorité moyen pondéré
SELECT
    AVG(CASE
        WHEN suggested_follow_up_date <= CURRENT_DATE THEN priority_score * 1.5
        ELSE priority_score
    END) as weighted_avg_priority
FROM mart_active_applications;