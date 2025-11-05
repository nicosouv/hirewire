"""
Gamification API Endpoints
Achievements, badges, points, and leaderboard
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func, text
from typing import List
from datetime import date

from app.core.security import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.models.gamification import Achievement, UserAchievement, UserStats, ActivityLog
from app.schemas.gamification import (
    AchievementResponse,
    UserAchievementResponse,
    UserStatsResponse,
    GamificationDashboard,
    LeaderboardEntry,
    ActivityLogCreate,
    AchievementUnlocked,
)

router = APIRouter()


def get_or_create_user_stats(db: Session, user_id: int) -> UserStats:
    """Get or create user stats"""
    stats = db.query(UserStats).filter(UserStats.user_id == user_id).first()
    if not stats:
        stats = UserStats(user_id=user_id)
        db.add(stats)
        db.commit()
        db.refresh(stats)
    return stats


def calculate_level(total_points: int) -> int:
    """Calculate user level based on points"""
    # Level = floor(sqrt(points / 100))
    # Level 1: 0-99 points
    # Level 2: 100-399 points
    # Level 3: 400-899 points
    # Level 4: 900-1599 points
    # etc.
    import math

    return max(1, int(math.sqrt(total_points / 100)) + 1)


def points_for_next_level(current_level: int) -> int:
    """Calculate points needed for next level"""
    # Inverse of level formula: points = (level - 1)^2 * 100
    return (current_level) ** 2 * 100


@router.get("/dashboard", response_model=GamificationDashboard)
def get_gamification_dashboard(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """
    Get complete gamification dashboard for current user
    Includes stats, achievements, and progress
    """
    # Get or create stats
    stats = get_or_create_user_stats(db, current_user.id)

    # Update level
    current_level = calculate_level(stats.total_points)
    if stats.level != current_level:
        stats.level = current_level
        db.commit()
        db.refresh(stats)

    # Get all achievements
    all_achievements = db.query(Achievement).filter(Achievement.is_active.is_(True)).all()

    # Get user's unlocked achievements
    unlocked = (
        db.query(UserAchievement)
        .filter(UserAchievement.user_id == current_user.id)
        .order_by(UserAchievement.unlocked_at.desc())
        .all()
    )

    # Get recent achievements (last 5)
    recent_achievements = unlocked[:5]

    # Calculate available achievements (not unlocked yet)
    unlocked_ids = {ua.achievement_id for ua in unlocked}
    available = [a for a in all_achievements if a.id not in unlocked_ids]

    # Calculate progress to next level
    next_level_points = points_for_next_level(stats.level)
    current_level_points = (
        points_for_next_level(stats.level - 1) if stats.level > 1 else 0
    )
    points_in_level = stats.total_points - current_level_points
    points_needed = next_level_points - current_level_points
    progress = (points_in_level / points_needed * 100) if points_needed > 0 else 0

    return GamificationDashboard(
        stats=stats,
        recent_achievements=recent_achievements,
        progress_to_next_level=round(progress, 1),
        next_level_points=next_level_points,
        all_achievements=all_achievements,
        unlocked_achievements=unlocked,
        available_achievements=available,
    )


@router.get("/stats", response_model=UserStatsResponse)
def get_user_stats(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """Get current user's stats"""
    stats = get_or_create_user_stats(db, current_user.id)

    # Update level
    current_level = calculate_level(stats.total_points)
    if stats.level != current_level:
        stats.level = current_level
        db.commit()
        db.refresh(stats)

    return stats


@router.get("/achievements", response_model=List[AchievementResponse])
def get_all_achievements(
    db: Session = Depends(get_db), current_user: User = Depends(get_current_user)
):
    """Get all available achievements"""
    achievements = (
        db.query(Achievement)
        .filter(Achievement.is_active.is_(True))
        .order_by(Achievement.category, Achievement.points)
        .all()
    )

    return achievements


@router.get("/achievements/unlocked", response_model=List[UserAchievementResponse])
def get_unlocked_achievements(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """Get user's unlocked achievements"""
    unlocked = (
        db.query(UserAchievement)
        .filter(UserAchievement.user_id == current_user.id)
        .order_by(UserAchievement.unlocked_at.desc())
        .all()
    )

    return unlocked


@router.post("/achievements/mark-seen")
def mark_achievements_as_seen(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """Mark all new achievements as seen"""
    db.query(UserAchievement).filter(
        UserAchievement.user_id == current_user.id, UserAchievement.is_new.is_(True)
    ).update({"is_new": False})

    db.commit()

    return {"message": "Achievements marked as seen"}


@router.post("/check-achievements", response_model=List[AchievementUnlocked])
def check_and_unlock_achievements(
    current_user: User = Depends(get_current_user), db: Session = Depends(get_db)
):
    """
    Check user's progress and unlock eligible achievements
    Returns newly unlocked achievements
    """
    # Call the PostgreSQL function to check achievements
    result = db.execute(
        text("SELECT * FROM hirewire.check_achievements(:user_id)"),
        {"user_id": current_user.id},
    )

    newly_unlocked = []
    for row in result:
        achievement = (
            db.query(Achievement)
            .filter(Achievement.id == row.newly_unlocked_id)
            .first()
        )

        if achievement:
            newly_unlocked.append(
                AchievementUnlocked(
                    achievement_id=achievement.id,
                    achievement_code=achievement.code,
                    name=achievement.name,
                    description=achievement.description,
                    icon=achievement.icon,
                    points=achievement.points,
                    rarity=achievement.rarity,
                )
            )

    return newly_unlocked


@router.get("/leaderboard", response_model=List[LeaderboardEntry])
def get_leaderboard(
    limit: int = 10,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Get leaderboard (top users by points)
    """
    # Get top users
    leaderboard_query = (
        db.query(
            UserStats,
            User.first_name,
            User.last_name,
            func.rank().over(order_by=UserStats.total_points.desc()).label("rank"),
        )
        .join(User, UserStats.user_id == User.id)
        .filter(UserStats.total_points > 0)
        .order_by(UserStats.total_points.desc())
        .limit(limit)
    )

    leaderboard = []
    for stats, first_name, last_name, rank in leaderboard_query:
        leaderboard.append(
            LeaderboardEntry(
                rank=rank,
                user_id=stats.user_id,
                full_name=f"{first_name} {last_name}",
                total_points=stats.total_points,
                level=stats.level,
                achievements_count=stats.achievements_count,
                is_current_user=(stats.user_id == current_user.id),
            )
        )

    # If current user is not in top, add them at the end
    current_user_in_list = any(
        entry.user_id == current_user.id for entry in leaderboard
    )

    if not current_user_in_list:
        current_stats = get_or_create_user_stats(db, current_user.id)

        # Get current user's rank
        rank_query = (
            db.query(func.count(UserStats.id))
            .filter(UserStats.total_points > current_stats.total_points)
            .scalar()
        )

        current_rank = (rank_query or 0) + 1

        leaderboard.append(
            LeaderboardEntry(
                rank=current_rank,
                user_id=current_user.id,
                full_name=current_user.full_name,
                total_points=current_stats.total_points,
                level=current_stats.level,
                achievements_count=current_stats.achievements_count,
                is_current_user=True,
            )
        )

    return leaderboard


@router.post("/activity")
def log_activity(
    activity: ActivityLogCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """
    Log user activity for streak calculation
    """
    # Get or create stats
    stats = get_or_create_user_stats(db, current_user.id)

    activity_date = activity.activity_date or date.today()

    # Check if activity already logged for today
    existing = (
        db.query(ActivityLog)
        .filter(
            ActivityLog.user_id == current_user.id,
            ActivityLog.activity_date == activity_date,
            ActivityLog.activity_type == activity.activity_type,
        )
        .first()
    )

    if existing:
        return {"message": "Activity already logged"}

    # Create activity log
    log = ActivityLog(
        user_id=current_user.id,
        activity_type=activity.activity_type,
        activity_date=activity_date,
        activity_metadata=activity.activity_metadata,
    )
    db.add(log)

    # Update streak
    if stats.last_activity_date:
        days_diff = (activity_date - stats.last_activity_date).days

        if days_diff == 1:
            # Consecutive day - increment streak
            stats.current_streak += 1
        elif days_diff > 1:
            # Streak broken - reset
            stats.current_streak = 1
        # If days_diff == 0, same day - don't change streak

    else:
        # First activity
        stats.current_streak = 1

    # Update longest streak
    if stats.current_streak > stats.longest_streak:
        stats.longest_streak = stats.current_streak

    stats.last_activity_date = activity_date
    stats.updated_at = func.now()

    db.commit()

    # Check for newly unlocked achievements
    newly_unlocked = db.execute(
        text("SELECT * FROM hirewire.check_achievements(:user_id)"),
        {"user_id": current_user.id},
    ).fetchall()

    return {
        "message": "Activity logged",
        "current_streak": stats.current_streak,
        "newly_unlocked": len(newly_unlocked),
    }
