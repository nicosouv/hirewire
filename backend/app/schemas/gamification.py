"""
Gamification Schemas (Pydantic)
Request/Response models for gamification API endpoints
"""

from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime, date


class AchievementBase(BaseModel):
    """Base achievement schema"""

    code: str
    name: str
    description: str
    category: str  # applications, interviews, streak, special
    icon: str
    points: int
    rarity: str  # common, rare, epic, legendary
    criteria: Dict[str, Any]


class AchievementResponse(AchievementBase):
    """Achievement response schema"""

    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserAchievementResponse(BaseModel):
    """User achievement response"""

    id: int
    user_id: int
    achievement_id: int
    unlocked_at: datetime
    progress: int
    is_new: bool
    achievement: AchievementResponse

    class Config:
        from_attributes = True


class UserStatsResponse(BaseModel):
    """User stats response"""

    id: int
    user_id: int
    total_points: int
    level: int
    applications_count: int
    interviews_count: int
    offers_count: int
    current_streak: int
    longest_streak: int
    last_activity_date: Optional[date]
    achievements_count: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class GamificationDashboard(BaseModel):
    """Complete gamification dashboard"""

    stats: UserStatsResponse
    recent_achievements: List[UserAchievementResponse]
    progress_to_next_level: float
    next_level_points: int
    all_achievements: List[AchievementResponse]
    unlocked_achievements: List[UserAchievementResponse]
    available_achievements: List[AchievementResponse]


class LeaderboardEntry(BaseModel):
    """Leaderboard entry"""

    rank: int
    user_id: int
    full_name: str
    total_points: int
    level: int
    achievements_count: int
    is_current_user: bool = False


class ActivityLogCreate(BaseModel):
    """Create activity log"""

    activity_type: str = Field(
        ..., description="application, interview, profile_update, login"
    )
    activity_date: Optional[date] = None
    activity_metadata: Optional[Dict[str, Any]] = None


class AchievementUnlocked(BaseModel):
    """Achievement unlocked notification"""

    achievement_id: int
    achievement_code: str
    name: str
    description: str
    icon: str
    points: int
    rarity: str
