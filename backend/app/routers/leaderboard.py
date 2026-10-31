from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.db.models import User
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.leaderboard import LeaderboardResponseOut
from app.services.leaderboard import get_leaderboard

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])


@router.get("", response_model=LeaderboardResponseOut)
async def read_leaderboard(
    scope: str = Query("week", description="today | week | month | all_time"),
    limit: int = Query(50, ge=1, le=100, description="Max entries to return"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> LeaderboardResponseOut:
    """Fetch aggregated step leaderboard and current user ranking."""
    return await get_leaderboard(
        caller_user_id=current_user.id,
        scope=scope,
        limit=limit,
        session=session,
        settings=settings,
    )
