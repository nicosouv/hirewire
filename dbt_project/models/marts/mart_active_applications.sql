{{ config(materialized='table') }}

WITH active_processes AS (
    SELECT
        p.id as process_id,
        p.job_position_id,
        p.application_date,
        p.status as current_status,
        p.source,
        p.notes as process_notes,
        p.created_at,
        p.updated_at
    FROM {{ ref('stg_interview_processes') }} p
    LEFT JOIN {{ ref('stg_interview_outcomes') }} o ON p.id = o.process_id
    WHERE
        -- No final outcome recorded yet
        o.process_id IS NULL
        OR
        -- Or outcome is not final (still in progress)
        o.outcome NOT IN ('rejection', 'rejected', 'offer', 'accepted', 'ghosted', 'withdrew')
),

job_details AS (
    SELECT
        jp.id as job_position_id,
        jp.title,
        jp.department,
        jp.level,
        jp.employment_type,
        jp.remote_policy,
        jp.salary_min,
        jp.salary_max,
        jp.currency,
        c.name as company_name,
        c.industry,
        c.size as company_size,
        c.location as company_location
    FROM {{ ref('stg_job_positions') }} jp
    JOIN {{ ref('stg_companies') }} c ON jp.company_id = c.id
),

recent_interviews AS (
    SELECT
        i.process_id,
        MAX(CASE WHEN i.status = 'completed' THEN i.scheduled_date END) as last_completed_interview_date,
        MAX(CASE WHEN i.status = 'scheduled' THEN i.scheduled_date END) as next_scheduled_interview_date,
        MAX(i.scheduled_date) as last_interview_date, -- All interviews (completed + scheduled)
        COUNT(CASE WHEN i.status = 'completed' THEN 1 END) as completed_interviews,
        COUNT(CASE WHEN i.status = 'scheduled' THEN 1 END) as scheduled_interviews,
        COUNT(*) as total_interviews,
        MAX(CASE WHEN i.status = 'completed' THEN i.interview_round END) as current_round,
        STRING_AGG(DISTINCT CASE WHEN i.status = 'completed' THEN i.interview_type END, ', ') as interview_types_completed,
        STRING_AGG(DISTINCT CASE WHEN i.status = 'scheduled' THEN i.interview_type END, ', ') as interview_types_scheduled
    FROM {{ ref('stg_interviews') }} i
    WHERE i.status IN ('completed', 'scheduled')
    GROUP BY i.process_id
)

SELECT
    ap.process_id,
    jd.company_name,
    jd.title as job_title,
    jd.department,
    jd.level,
    jd.employment_type,
    jd.remote_policy,
    jd.salary_min,
    jd.salary_max,
    jd.currency,
    jd.industry,
    jd.company_size,
    jd.company_location,
    ap.application_date,
    ap.current_status,
    ap.source,
    CURRENT_DATE - ap.application_date as days_since_application,
    ri.last_interview_date,
    ri.last_completed_interview_date,
    ri.next_scheduled_interview_date,
    CASE
        WHEN ri.last_interview_date IS NOT NULL
        THEN CURRENT_DATE - ri.last_interview_date::DATE
        ELSE NULL
    END as days_since_last_interview,
    COALESCE(ri.total_interviews, 0) as total_interviews,
    COALESCE(ri.completed_interviews, 0) as completed_interviews,
    COALESCE(ri.scheduled_interviews, 0) as scheduled_interviews,
    COALESCE(ri.current_round, 0) as current_round,
    ri.interview_types_completed,
    ri.interview_types_scheduled,
    ap.process_notes,
    ap.created_at,
    ap.updated_at,
    -- Status categorization for better filtering
    CASE
        WHEN ap.current_status IN ('applied') THEN 'Waiting for Response'
        WHEN ap.current_status IN ('screening') THEN 'In Screening'
        WHEN ap.current_status IN ('interviewing') THEN 'In Interview Process'
        WHEN ap.current_status IN ('offer') THEN 'Offer Stage'
        ELSE 'Other'
    END as status_category,
    -- Priority scoring based on recency, stage, and scheduled interviews
    CASE
        WHEN ap.current_status = 'offer' THEN 100
        -- High priority for upcoming scheduled interviews
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE
             AND (ri.next_scheduled_interview_date::DATE - CURRENT_DATE) <= 3 THEN 95  -- Within 3 days
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE
             AND (ri.next_scheduled_interview_date::DATE - CURRENT_DATE) <= 7 THEN 90   -- Within 1 week
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE THEN 85 -- Future interviews
        -- Recently completed interviews awaiting results
        WHEN ap.current_status = 'interviewing' AND ri.last_completed_interview_date IS NOT NULL
             AND (CURRENT_DATE - ri.last_completed_interview_date::DATE) <= 7 THEN 90
        WHEN ap.current_status = 'interviewing' THEN 80
        WHEN ap.current_status = 'screening' THEN 70
        WHEN ap.current_status = 'applied' AND (CURRENT_DATE - ap.application_date) <= 14 THEN 60
        WHEN ap.current_status = 'applied' THEN 50
        ELSE 40
    END as priority_score,

    -- Next action recommendation (specific based on interview types)
    CASE
        WHEN ap.current_status = 'offer' THEN 'Négocier/Répondre à l''offre'

        -- Handle scheduled interviews with specific actions based on type
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%phone_screening%' THEN 'Préparer entretien téléphonique'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%hr_screening%' THEN 'Préparer entretien RH'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%video_screening%' THEN 'Préparer entretien vidéo'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%recruiter_call%' THEN 'Préparer appel recruteur'

        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%technical_interview%' THEN 'Préparer entretien technique'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%technical_video%' THEN 'Préparer entretien technique vidéo'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%coding_challenge%' THEN 'Préparer test de code'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%system_design%' THEN 'Préparer entretien system design'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%pair_programming%' THEN 'Préparer session pair programming'

        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%final_interview%' THEN 'Préparer entretien final'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%manager_interview%' THEN 'Préparer entretien manager'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%cultural_fit%' THEN 'Préparer entretien culture/fit'
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE AND
             ri.interview_types_scheduled ILIKE '%executive_interview%' THEN 'Préparer entretien direction'

        -- Generic fallback for scheduled interviews
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date >= CURRENT_DATE THEN 'Préparer prochaine étape'

        -- Past scheduled interviews awaiting results
        WHEN ri.next_scheduled_interview_date IS NOT NULL AND ri.next_scheduled_interview_date < CURRENT_DATE THEN 'Attendre résultat entretien'

        -- Handle based on current status and completed interviews
        WHEN ap.current_status = 'interviewing' AND ri.last_completed_interview_date IS NOT NULL
             AND (CURRENT_DATE - ri.last_completed_interview_date::DATE) > 10 THEN 'Relancer pour feedback'
        WHEN ap.current_status = 'interviewing' THEN 'Préparer prochaine étape'
        WHEN ap.current_status = 'screening' AND ri.last_completed_interview_date IS NOT NULL
             AND (CURRENT_DATE - ri.last_completed_interview_date::DATE) > 7 THEN 'Demander feedback screening'
        WHEN ap.current_status = 'screening' THEN 'Attendre résultat screening'
        WHEN ap.current_status = 'tech_test' THEN 'Finaliser le test technique'
        WHEN ap.current_status = 'final_round' THEN 'Préparer entretien final'
        WHEN ap.current_status = 'reminder' THEN 'Relancer la candidature'
        WHEN ap.current_status = 'applied' AND (CURRENT_DATE - ap.application_date) > 14 THEN 'Relancer'
        WHEN ap.current_status = 'applied' AND (CURRENT_DATE - ap.application_date) > 7 THEN 'Préparer relance'
        WHEN ap.current_status = 'applied' THEN 'Attendre réponse'
        ELSE 'Évaluer la situation'
    END as next_action,

    -- Expected next step in the process
    CASE
        WHEN ap.current_status = 'applied' THEN 'Screening/Premier contact'
        WHEN ap.current_status = 'screening' THEN 'Entretien technique'
        WHEN ap.current_status = 'tech_test' THEN 'Entretien technique/validation'
        WHEN ap.current_status = 'interviewing' AND ri.current_round = 1 THEN 'Entretien final/manager'
        WHEN ap.current_status = 'interviewing' THEN 'Entretien final'
        WHEN ap.current_status = 'final_round' THEN 'Décision/Offre'
        WHEN ap.current_status = 'offer' THEN 'Négociation/Acceptation'
        WHEN ap.current_status = 'reminder' THEN 'Réponse à la relance'
        ELSE 'À déterminer'
    END as expected_next_step,

    -- Suggested follow-up date
    CASE
        WHEN ap.current_status = 'offer' THEN CURRENT_DATE + INTERVAL '2 days'
        WHEN ap.current_status = 'interviewing' AND ri.last_interview_date IS NOT NULL
             AND (CURRENT_DATE - ri.last_interview_date::DATE) > 7 THEN CURRENT_DATE + INTERVAL '1 day'
        WHEN ap.current_status = 'interviewing' THEN CURRENT_DATE + INTERVAL '5 days'
        WHEN ap.current_status = 'screening' AND ri.last_interview_date IS NOT NULL THEN
             ri.last_interview_date::DATE + INTERVAL '7 days'
        WHEN ap.current_status = 'tech_test' THEN CURRENT_DATE + INTERVAL '3 days'
        WHEN ap.current_status = 'final_round' THEN CURRENT_DATE + INTERVAL '3 days'
        WHEN ap.current_status = 'reminder' THEN CURRENT_DATE + INTERVAL '7 days'
        WHEN ap.current_status = 'applied' AND (CURRENT_DATE - ap.application_date) > 14 THEN CURRENT_DATE + INTERVAL '1 day'
        WHEN ap.current_status = 'applied' THEN ap.application_date + INTERVAL '14 days'
        ELSE CURRENT_DATE + INTERVAL '7 days'
    END as suggested_follow_up_date
FROM active_processes ap
JOIN job_details jd ON ap.job_position_id = jd.job_position_id
LEFT JOIN recent_interviews ri ON ap.process_id = ri.process_id
ORDER BY priority_score DESC, ap.application_date DESC