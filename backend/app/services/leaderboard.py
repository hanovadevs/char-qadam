"""Leaderboard aggregation business logic.

Ranks active users by verified step activity over configurable scopes:
- ``today``: Steps logged on today's local date.
- ``week``: Steps logged over the past 7 days (rolling window).
- ``month``: Steps logged over the past 30 days (rolling window).
- ``all_time``: Cumulative lifetime step totals.

Features:
- Pseudonymous walker labels that do not reveal email addresses.
- Computes caller's exact rank and percentile even if outside top N.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.services.local_date import local_today
from app.db.models import ActivityDaily, User, UserStatus
from app.schemas.leaderboard import (
    LeaderboardEntryOut,
    LeaderboardResponseOut,
    UserRankingOut,
)


async def get_leaderboard(
    *,
    caller_user_id: str,
    scope: str = "week",
    limit: int = 50,
    session: AsyncSession,
    settings: Settings,
) -> LeaderboardResponseOut:
    """Aggregate verified steps and rank users by total volume."""
    now = local_today()
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

    totals = (
        select(
            User.id.label("user_id"), User.country, User.created_at,
            func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).label("total_steps"),
        )
        .outerjoin(
            ActivityDaily,
            (ActivityDaily.user_id == User.id) & date_filter
            if date_filter is not None else ActivityDaily.user_id == User.id,
        )
        .where(User.status == UserStatus.ACTIVE)
        .group_by(User.id, User.country, User.created_at)
        .subquery()
    )
    ranked = select(
        totals,
        func.row_number().over(order_by=(totals.c.total_steps.desc(), totals.c.created_at.asc(), totals.c.user_id.asc())).label("rank"),
        func.count().over().label("participants"),
    ).subquery()
    # Transfer only the visible page and caller, rather than every user's data.
    rows = (await session.execute(
        select(ranked).where(or_(ranked.c.rank <= limit, ranked.c.user_id == caller_user_id))
        .order_by(ranked.c.rank)
    )).all()
    total_participants = int(rows[0].participants) if rows else 0
    rankings = []
    user_ranking = None
    steps_per_point = settings.steps_per_point if settings.steps_per_point > 0 else 100
    for row in rows:
        rank, steps = int(row.rank), int(row.total_steps)
        points = steps // steps_per_point
        is_caller = row.user_id == caller_user_id
        if rank <= limit:
            rankings.append(LeaderboardEntryOut(
                rank=rank, user_id=row.user_id, display_name="Walker " + row.user_id.replace("-", "")[:8],
                total_steps=steps, points_earned=points, country=row.country or "PK",
                is_current_user=is_caller,
            ))
        if is_caller:
            user_ranking = UserRankingOut(
                rank=rank, total_steps=steps, points_earned=points,
                total_participants=total_participants,
                percentile=round(rank / total_participants * 100.0, 1),
            )
    return LeaderboardResponseOut(
        scope=scope, total_participants=total_participants,
        rankings=rankings, user_ranking=user_ranking,
    )
