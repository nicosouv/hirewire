"""
Gamification Models
Achievements, badges, points, and user stats
"""

from datetime import datetime, date
from sqlalchemy import Column, Integer, String, Boolean, TIMESTAMP, ForeignKey, Text, Date, CheckConstraint
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from app.db.base import Base


class Achievement(Base):
    """Achievement/Badge catalog"""

    __tablename__ = "achievements"
    __table_args__ = {'schema': 'hirewire'}

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(100), unique=True, nullable=False, index=True)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    category = Column(String(50), nullable=False)  # applications, interviews, streak, special
    icon = Column(String(50), nullable=False)  # emoji or icon name
    points = Column(Integer, nullable=False, default=0)
    rarity = Column(String(20), nullable=False, default='common')  # common, rare, epic, legendary
    criteria = Column(JSONB, nullable=False)  # {type: 'count', target: 10, metric: 'applications'}
    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)

    # Relationships
    user_achievements = relationship("UserAchievement", back_populates="achievement", cascade="all, delete-orphan")


class UserAchievement(Base):
    """User's unlocked achievements"""

    __tablename__ = "user_achievements"
    __table_args__ = {'schema': 'hirewire'}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("hirewire.users.id", ondelete="CASCADE"), nullable=False, index=True)
    achievement_id = Column(Integer, ForeignKey("hirewire.achievements.id", ondelete="CASCADE"), nullable=False, index=True)
    unlocked_at = Column(TIMESTAMP, default=datetime.utcnow, nullable=False)
    progress = Column(Integer, default=0)
    is_new = Column(Boolean, default=True)

    # Relationships
    user = relationship("User", back_populates="achievements")
    achievement = relationship("Achievement", back_populates="user_achievements")


class UserStats(Base):
    """User statistics for gamification"""

    __tablename__ = "user_stats"
    __table_args__ = {'schema': 'hirewire'}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("hirewire.users.id", ondelete="CASCADE"), unique=True, nullable=False, index=True)
    total_points = Column(Integer, default=0, index=True)
    level = Column(Integer, default=1)
    applications_count = Column(Integer, default=0)
    interviews_count = Column(Integer, default=0)
    offers_count = Column(Integer, default=0)
    current_streak = Column(Integer, default=0)
    longest_streak = Column(Integer, default=0)
    last_activity_date = Column(Date)
    achievements_count = Column(Integer, default=0)
    created_at = Column(TIMESTAMP, default=datetime.utcnow, nullable=False)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="stats", uselist=False)


class ActivityLog(Base):
    """Activity log for streak calculation"""

    __tablename__ = "activity_log"
    __table_args__ = {'schema': 'hirewire'}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("hirewire.users.id", ondelete="CASCADE"), nullable=False, index=True)
    activity_type = Column(String(50), nullable=False)  # application, interview, profile_update, login
    activity_date = Column(Date, nullable=False, default=date.today, index=True)
    activity_metadata = Column(JSONB)
    created_at = Column(TIMESTAMP, default=datetime.utcnow, nullable=False)

    # Relationships
    user = relationship("User", back_populates="activity_logs")
