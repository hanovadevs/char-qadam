from __future__ import annotations

from typing import List, Optional
# pyrefly: ignore [missing-import]
from pydantic import BaseModel, Field


class LeaderboardEntryOut(BaseModel):
    rank: int = Field(..., description="1-based position in leaderboard")
    user_id: str = Field(..., description="UUID of the user")
    display_name: str = Field(..., description="Privacy-masked display name")
    total_steps: int = Field(..., description="Total eligible steps in the period")
    points_earned: int = Field(..., description="Total points earned from steps in period")
    country: Optional[str] = Field("PK", description="User country code")
    is_current_user: bool = Field(False, description="True if this row is the authenticated caller")


class UserRankingOut(BaseModel):
    rank: int = Field(..., description="1-based rank of current user")
    total_steps: int = Field(..., description="Total steps in period")
    points_earned: int = Field(..., description="Total points earned in period")
    total_participants: int = Field(..., description="Total active users in leaderboard")
    percentile: float = Field(..., description="Top percentile (e.g. 5.0 for Top 5%)")


class LeaderboardResponseOut(BaseModel):
    scope: str = Field(..., description="today | week | month | all_time")
    total_participants: int = Field(..., description="Total active participants")
    rankings: List[LeaderboardEntryOut] = Field(default_factory=list)
    user_ranking: Optional[UserRankingOut] = None
