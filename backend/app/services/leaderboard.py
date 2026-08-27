"""Leaderboard aggregation business logic.

Ranks active users by verified step activity over configurable scopes:
- ``today``: Steps logged on today's local date.
- ``week``: Steps logged over the past 7 days (rolling window).
- ``month``: Steps logged over the past 30 days (rolling window).
- ``all_time``: Cumulative lifetime step totals.

Features:
- Privacy-masked display names (e.g. ``ali****@gmail.com``).
- Computes caller's exact rank and percentile even if outside top N.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.db.models import ActivityDaily, User, UserStatus
from app.schemas.leaderboard import (
    LeaderboardEntryOut,
    LeaderboardResponseOut,
    UserRankingOut,
)


def _mask_email(email: str) -> str:
    """Mask email for privacy, e.g. 'athlete123@domain.com' -> 'ath****@domain.com'."""
    if not email or "@" not in email:
        return "Walker"
    local, domain = email.split("@", 1)
    if len(local) <= 2:
        masked_local = local[0] + "*"
    elif len(local) <= 4:
        masked_local = local[:2] + "**"
    else:
        masked_local = local[:3] + "****"
    return f"{masked_local}@{domain}"


async def get_leaderboard(
    *,
    caller_user_id: str,
    scope: str = "week",
    limit: int = 50,
    session: AsyncSession,
    settings: Settings,
) -> LeaderboardResponseOut:
    """Aggregate verified steps and rank users by total volume."""
    now = datetime.now(timezone.utc)
    today_str = now.strftime("%Y-%m-%d")

    date_filter = None
    if scope == "today":
        date_filter = ActivityDaily.local_date == today_str
    elif scope == "week":
        week_start_str = (now - timedelta(days=6)).strftime("%Y-%m-%d")
        date_filter = ActivityDaily.local_date >= week_start_str
    elif scope == "month":
        month_start_str = (now - timedelta(days=29)).strftime("%Y-%m-%d")
        date_filter = ActivityDaily.local_date >= month_start_str
    elif scope == "all_time":
        date_filter = None
    else:
        # Default to week if invalid
        scope = "week"
        week_start_str = (now - timedelta(days=6)).strftime("%Y-%m-%d")
        date_filter = ActivityDaily.local_date >= week_start_str

    if date_filter is not None:
        stmt = (
            select(
                User.id.label("user_id"),
                User.email.label("email"),
                User.country.label("country"),
                func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).label("total_steps"),
            )
            .outerjoin(
                ActivityDaily,
                (ActivityDaily.user_id == User.id) & date_filter,
            )
            .where(User.status == UserStatus.ACTIVE)
            .group_by(User.id, User.email, User.country)
            .order_by(
                func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).desc(),
                User.created_at.asc(),
            )
        )
    else:
        stmt = (
            select(
                User.id.label("user_id"),
                User.email.label("email"),
                User.country.label("country"),
                func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).label("total_steps"),
            )
            .outerjoin(ActivityDaily, ActivityDaily.user_id == User.id)
            .where(User.status == UserStatus.ACTIVE)
            .group_by(User.id, User.email, User.country)
            .order_by(
                func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).desc(),
                User.created_at.asc(),
            )
        )

    result = await session.execute(stmt)
    rows = result.all()

    total_participants = len(rows)
    rankings: list[LeaderboardEntryOut] = []
    user_ranking: Optional[UserRankingOut] = None

    steps_per_point = settings.steps_per_point if settings.steps_per_point > 0 else 100

    for idx, row in enumerate(rows):
        rank = idx + 1
        u_id = row.user_id
        u_email = row.email
        u_country = row.country or "PK"
        u_steps = int(row.total_steps)
        u_points = u_steps // steps_per_point
        is_caller = u_id == caller_user_id

        entry = LeaderboardEntryOut(
            rank=rank,
            user_id=u_id,
            display_name=_mask_email(u_email),
            total_steps=u_steps,
            points_earned=u_points,
            country=u_country,
            is_current_user=is_caller,
        )

        if rank <= limit:
            rankings.append(entry)

        if is_caller:
            percentile = (
                round((rank / total_participants) * 100.0, 1)
                if total_participants > 0
                else 100.0
            )
            user_ranking = UserRankingOut(
                rank=rank,
                total_steps=u_steps,
                points_earned=u_points,
                total_participants=total_participants,
                percentile=percentile,
            )

    return LeaderboardResponseOut(
        scope=scope,
        total_participants=total_participants,
        rankings=rankings,
        user_ranking=user_ranking,
    )
