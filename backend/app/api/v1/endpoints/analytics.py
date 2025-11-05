"""
Analytics API endpoints for visualizations (Sankey, etc.)
"""

from typing import Dict, Optional
from datetime import date
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import text

from app.db.session import get_db
from app.core.security import get_current_user
from app.models.user import User

router = APIRouter()


@router.get("/sankey/status-flow", response_model=Dict)
def get_status_flow_sankey(
    start_date: Optional[date] = Query(
        None, description="Filter processes from this date"
    ),
    end_date: Optional[date] = Query(
        None, description="Filter processes until this date"
    ),
    outcome_filter: Optional[str] = Query(
        None, description="Filter by outcome (rejected, accepted, ghosted, withdrew)"
    ),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get Sankey diagram data for application status flow.

    Flow: Applied → Screening → Interviewing → Final Round → Outcomes

    Returns nodes and links for Plotly Sankey diagram.
    """
    # Build date filter
    date_filter = ""
    params = {"user_id": current_user.id}

    if start_date:
        date_filter += " AND ip.application_date >= :start_date"
        params["start_date"] = start_date

    if end_date:
        date_filter += " AND ip.application_date <= :end_date"
        params["end_date"] = end_date

    # Build outcome filter
    outcome_filter_sql = ""
    if outcome_filter:
        outcome_filter_sql = " AND io.outcome = :outcome_filter"
        params["outcome_filter"] = outcome_filter

    # Create multi-stage flow: Applied → Interview Rounds → Status/Outcome
    # This query creates flows showing the interview journey
    query = text(
        f"""
        WITH process_interviews AS (
            -- Get all processes with their interview progression
            SELECT
                ip.id as process_id,
                io.outcome,
                ip.status,
                COUNT(DISTINCT CASE WHEN i.interview_type IN ('screening', 'video_screening', 'hr') THEN i.id END) as screening_count,  # noqa: E501
                COUNT(DISTINCT CASE WHEN i.interview_type IN ('technical', 'technical_video', 'coding_challenge', 'system_design') THEN i.id END) as technical_count,  # noqa: E501
                COUNT(DISTINCT CASE WHEN i.interview_type = 'behavioral' THEN i.id END) as behavioral_count,
                COUNT(DISTINCT i.id) as total_interviews,
                -- Determine stage based on interview progression (not just type)
                CASE
                    WHEN COUNT(DISTINCT i.id) = 0 THEN 'none'
                    WHEN COUNT(DISTINCT i.id) = 1 THEN 'first'
                    WHEN COUNT(DISTINCT i.id) = 2 THEN 'second'
                    WHEN COUNT(DISTINCT i.id) >= 3 THEN 'final'
                END as stage_reached
            FROM hirewire.interview_processes ip
            LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
            LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
            WHERE ip.user_id = :user_id
            {date_filter}
            {outcome_filter_sql}
            GROUP BY ip.id, io.outcome, ip.status
        ),
        flows AS (
            -- Stage 1: Applied → First Interview or No Interview
            SELECT
                'Applied' as source,
                CASE
                    WHEN total_interviews = 0 THEN 'No Interview'
                    WHEN total_interviews = 1 THEN '1 Interview'
                    WHEN total_interviews = 2 THEN '2 Interviews'
                    WHEN total_interviews >= 3 THEN '3+ Interviews'
                END as target,
                COUNT(*) as value,
                1 as stage
            FROM process_interviews
            GROUP BY 2

            UNION ALL

            -- Stage 2: 1 Interview → Outcome or 2 Interviews
            SELECT
                '1 Interview' as source,
                CASE
                    WHEN total_interviews > 1 THEN '2 Interviews'
                    WHEN outcome IS NOT NULL THEN
                        CASE outcome
                            WHEN 'accepted' THEN 'Accepted'
                            WHEN 'rejected' THEN 'Rejected'
                            WHEN 'rejection' THEN 'Rejected'
                            WHEN 'ghosted' THEN 'Ghosted'
                            WHEN 'withdrew' THEN 'Withdrew'
                            WHEN 'offer' THEN 'Offer'
                            ELSE 'Other Outcome'
                        END
                    ELSE 'In Progress'
                END as target,
                COUNT(*) as value,
                2 as stage
            FROM process_interviews
            WHERE total_interviews >= 1
            GROUP BY 2

            UNION ALL

            -- Stage 3: 2 Interviews → Outcome or 3+ Interviews
            SELECT
                '2 Interviews' as source,
                CASE
                    WHEN total_interviews > 2 THEN '3+ Interviews'
                    WHEN outcome IS NOT NULL THEN
                        CASE outcome
                            WHEN 'accepted' THEN 'Accepted'
                            WHEN 'rejected' THEN 'Rejected'
                            WHEN 'rejection' THEN 'Rejected'
                            WHEN 'ghosted' THEN 'Ghosted'
                            WHEN 'withdrew' THEN 'Withdrew'
                            WHEN 'offer' THEN 'Offer'
                            ELSE 'Other Outcome'
                        END
                    ELSE 'In Progress'
                END as target,
                COUNT(*) as value,
                3 as stage
            FROM process_interviews
            WHERE total_interviews >= 2
            GROUP BY 2

            UNION ALL

            -- Stage 4: 3+ Interviews → Outcome
            SELECT
                '3+ Interviews' as source,
                CASE
                    WHEN outcome IS NOT NULL THEN
                        CASE outcome
                            WHEN 'accepted' THEN 'Accepted'
                            WHEN 'rejected' THEN 'Rejected'
                            WHEN 'rejection' THEN 'Rejected'
                            WHEN 'ghosted' THEN 'Ghosted'
                            WHEN 'withdrew' THEN 'Withdrew'
                            WHEN 'offer' THEN 'Offer'
                            ELSE 'Other Outcome'
                        END
                    ELSE 'In Progress'
                END as target,
                COUNT(*) as value,
                4 as stage
            FROM process_interviews
            WHERE total_interviews >= 3
            GROUP BY 2

            UNION ALL

            -- Stage 5: No Interview → Outcome
            SELECT
                'No Interview' as source,
                CASE
                    WHEN outcome IS NOT NULL THEN
                        CASE outcome
                            WHEN 'accepted' THEN 'Accepted'
                            WHEN 'rejected' THEN 'Rejected'
                            WHEN 'rejection' THEN 'Rejected'
                            WHEN 'ghosted' THEN 'Ghosted'
                            WHEN 'withdrew' THEN 'Withdrew'
                            WHEN 'offer' THEN 'Offer'
                            ELSE 'Other Outcome'
                        END
                    ELSE 'Still Applied'
                END as target,
                COUNT(*) as value,
                5 as stage
            FROM process_interviews
            WHERE total_interviews = 0
            GROUP BY 2
        )
        SELECT source, target, value
        FROM flows
        WHERE value > 0
        ORDER BY stage, source, target
    """
    )

    results = db.execute(query, params).fetchall()

    # Build nodes and links for Sankey
    nodes = []
    node_map = {}
    links = {"source": [], "target": [], "value": []}

    # Extract unique nodes
    all_nodes = set()
    for row in results:
        all_nodes.add(row[0])  # source
        all_nodes.add(row[1])  # target

    # Define node order and colors (progression-based)
    node_order = [
        "Applied",
        "No Interview",
        "1 Interview",
        "2 Interviews",
        "3+ Interviews",
        "Still Applied",
        "In Progress",
        "Offer",
        "Accepted",
        "Rejected",
        "Ghosted",
        "Withdrew",
        "Other Outcome",
    ]

    node_colors = {
        "Applied": "#3B82F6",  # blue (start)
        "No Interview": "#CBD5E1",  # light gray (no interview)
        "1 Interview": "#8B5CF6",  # purple (first round)
        "2 Interviews": "#EC4899",  # pink (second round)
        "3+ Interviews": "#F59E0B",  # amber (final rounds)
        "Still Applied": "#93C5FD",  # light blue (waiting)
        "In Progress": "#94A3B8",  # slate (ongoing)
        "Offer": "#10B981",  # green (positive)
        "Accepted": "#059669",  # dark green (success)
        "Rejected": "#EF4444",  # red (negative)
        "Ghosted": "#6B7280",  # gray (ghosted)
        "Withdrew": "#F97316",  # orange (withdrew)
        "Other Outcome": "#64748B",  # dark slate (other)
    }

    # Create ordered nodes list
    for node_name in node_order:
        if node_name in all_nodes:
            node_map[node_name] = len(nodes)
            nodes.append(
                {"label": node_name, "color": node_colors.get(node_name, "#94A3B8")}
            )

    # Create links
    for row in results:
        source_name = row[0]
        target_name = row[1]
        value = row[2]

        if source_name in node_map and target_name in node_map:
            links["source"].append(node_map[source_name])
            links["target"].append(node_map[target_name])
            links["value"].append(value)

    # Get statistics
    total_processes = db.execute(
        text(
            f"""
            SELECT COUNT(*) FROM hirewire.interview_processes ip
            WHERE ip.user_id = :user_id {date_filter}
        """
        ),
        params,
    ).scalar()

    return {
        "nodes": nodes,
        "links": links,
        "total_processes": total_processes,
        "filters": {
            "start_date": start_date.isoformat() if start_date else None,
            "end_date": end_date.isoformat() if end_date else None,
            "outcome_filter": outcome_filter,
        },
    }


@router.get("/sankey/company-flow", response_model=Dict)
def get_company_flow_sankey(
    start_date: Optional[date] = Query(
        None, description="Filter processes from this date"
    ),
    end_date: Optional[date] = Query(
        None, description="Filter processes until this date"
    ),
    limit: int = Query(10, description="Top N companies to show"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get Sankey diagram data for company-to-outcome flow.

    Flow: Company → Status/Outcome

    Shows which companies lead to which outcomes.
    """
    # Build date filter
    date_filter = ""
    params = {"user_id": current_user.id, "limit": limit}

    if start_date:
        date_filter += " AND ip.application_date >= :start_date"
        params["start_date"] = start_date

    if end_date:
        date_filter += " AND ip.application_date <= :end_date"
        params["end_date"] = end_date

    # Query for company to outcome flow
    query = text(
        f"""
        WITH company_outcomes AS (
            SELECT
                c.name as company_name,
                COALESCE(io.outcome, ip.status) as outcome_or_status,
                COUNT(*) as count
            FROM hirewire.interview_processes ip
            JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
            JOIN hirewire.companies c ON jp.company_id = c.id
            LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
            WHERE ip.user_id = :user_id {date_filter}
            GROUP BY c.name, COALESCE(io.outcome, ip.status)
        ),
        top_companies AS (
            SELECT company_name, SUM(count) as total
            FROM company_outcomes
            GROUP BY company_name
            ORDER BY total DESC
            LIMIT :limit
        )
        SELECT co.company_name, co.outcome_or_status, co.count
        FROM company_outcomes co
        JOIN top_companies tc ON co.company_name = tc.company_name
        ORDER BY tc.total DESC, co.count DESC
    """
    )

    results = db.execute(query, params).fetchall()

    # Build nodes and links
    companies = set()
    outcomes = set()

    for row in results:
        companies.add(row[0])
        outcomes.add(row[1])

    # Create nodes
    nodes = []
    node_map = {}

    # Add company nodes
    for company in sorted(companies):
        node_map[company] = len(nodes)
        nodes.append({"label": company, "color": "#3B82F6"})  # blue for companies

    # Add outcome nodes
    outcome_colors = {
        "applied": "#94A3B8",
        "screening": "#8B5CF6",
        "interviewing": "#EC4899",
        "tech_test": "#6366F1",
        "final_round": "#F59E0B",
        "offer": "#10B981",
        "accepted": "#059669",
        "rejected": "#EF4444",
        "ghosted": "#6B7280",
        "withdrew": "#F97316",
    }

    for outcome in sorted(outcomes):
        node_map[outcome] = len(nodes)
        nodes.append(
            {
                "label": outcome.replace("_", " ").title(),
                "color": outcome_colors.get(outcome, "#94A3B8"),
            }
        )

    # Create links
    links = {"source": [], "target": [], "value": []}

    for row in results:
        company = row[0]
        outcome = row[1]
        count = row[2]

        links["source"].append(node_map[company])
        links["target"].append(node_map[outcome])
        links["value"].append(count)

    # Get statistics
    total_companies = len(companies)
    total_processes = sum(row[2] for row in results)

    return {
        "nodes": nodes,
        "links": links,
        "total_companies": total_companies,
        "total_processes": total_processes,
        "filters": {
            "start_date": start_date.isoformat() if start_date else None,
            "end_date": end_date.isoformat() if end_date else None,
            "limit": limit,
        },
    }


@router.get("/stats/overview", response_model=Dict)
def get_analytics_overview(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """
    Get overview statistics for analytics dashboard.
    """
    stats_query = text(
        """
        SELECT
            COUNT(DISTINCT ip.id) as total_applications,
            COUNT(DISTINCT CASE WHEN ip.status NOT IN ('rejected', 'ghosted', 'withdrew')
                AND io.outcome IS NULL THEN ip.id END) as active_applications,
            COUNT(DISTINCT i.id) as total_interviews,
            COUNT(DISTINCT CASE WHEN io.outcome = 'accepted' THEN io.id END) as offers_accepted,
            COUNT(DISTINCT CASE WHEN io.outcome IN ('rejected', 'offer') THEN io.id END) as offers_received,
            COUNT(DISTINCT c.id) as total_companies,
            AVG(CASE WHEN io.outcome_date IS NOT NULL
                THEN (io.outcome_date - ip.application_date) END) as avg_days_to_outcome,
            COUNT(DISTINCT CASE WHEN EXISTS (
                SELECT 1 FROM hirewire.interviews i2
                WHERE i2.process_id = ip.id
            ) THEN ip.id END) as processes_with_interviews
        FROM hirewire.interview_processes ip
        LEFT JOIN hirewire.interviews i ON ip.id = i.process_id
        LEFT JOIN hirewire.interview_outcomes io ON ip.id = io.process_id
        JOIN hirewire.job_positions jp ON ip.job_position_id = jp.id
        JOIN hirewire.companies c ON jp.company_id = c.id
        WHERE ip.user_id = :user_id
    """
    )

    stats = db.execute(stats_query, {"user_id": current_user.id}).fetchone()

    total_applications = stats[0] or 0
    processes_with_interviews = stats[7] or 0

    return {
        "total_applications": total_applications,
        "active_applications": stats[1] or 0,
        "total_interviews": stats[2] or 0,
        "offers_accepted": stats[3] or 0,
        "offers_received": stats[4] or 0,
        "total_companies": stats[5] or 0,
        "avg_days_to_outcome": round(stats[6], 1) if stats[6] else 0,
        "conversion_rate": (
            round((stats[3] / total_applications * 100), 1) if total_applications else 0
        ),
        "first_interview_rate": (
            round((processes_with_interviews / total_applications * 100), 1)
            if total_applications
            else 0
        ),
    }
