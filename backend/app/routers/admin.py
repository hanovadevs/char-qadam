"""Admin router for partner provisioning, key management, fraud auditing, and maintenance."""
from __future__ import annotations

import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ActivityDaily, Partner, PartnerStatus, User, UserStatus
from app.db.postgres import get_session
from app.schemas.admin import (
    CreatePartnerIn,
    CreatePartnerOut,
    FraudAuditItemOut,
    SweepExpiredOut,
    UpdateUserStatusIn,
)
from app.services.partner_auth import hash_api_key
from app.services.voucher_sweep import sweep_expired_vouchers

router = APIRouter(prefix="/admin", tags=["admin"])


@router.post(
    "/partners",
    response_model=CreatePartnerOut,
    status_code=status.HTTP_201_CREATED,
    summary="Provision a new merchant partner and generate an API key",
)
async def create_partner(
    body: CreatePartnerIn,
    session: AsyncSession = Depends(get_session),
) -> CreatePartnerOut:
    """Create a new merchant partner record and generate a cryptographically secure API key.

    Returns the raw API key ONCE. The key is hashed with SHA-256 in the database.
    """
    # Check for duplicate partner name
    existing = await session.execute(
        select(Partner).where(Partner.name == body.name.strip())
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Partner '{body.name}' already exists",
        )

    # Generate a cryptographically secure 32-byte URL-safe API key
    raw_api_key = f"pk_live_{secrets.token_urlsafe(32)}"
    api_key_hash = hash_api_key(raw_api_key)

    partner = Partner(
        id=str(uuid.uuid4()),
        name=body.name.strip(),
        api_key_hash=api_key_hash,
        status=PartnerStatus.ACTIVE,
    )
    session.add(partner)
    await session.commit()

    return CreatePartnerOut(
        partner_id=partner.id,
        name=partner.name,
        status=partner.status.value,
        raw_api_key=raw_api_key,
    )


@router.post(
    "/vouchers/sweep-expired",
    response_model=SweepExpiredOut,
    summary="Trigger atomic expiration sweep on all past-due vouchers",
)
async def trigger_voucher_sweep(
    session: AsyncSession = Depends(get_session),
) -> SweepExpiredOut:
    """Sweep all vouchers with status='ISSUED' and expires_at < now() into 'EXPIRED' status."""
    result = await sweep_expired_vouchers(session)
    count = int(result["swept_count"])
    codes = list(result["swept_codes"])

    return SweepExpiredOut(
        swept_count=count,
        swept_codes=codes,
        message=f"Successfully transitioned {count} past-due vouchers to EXPIRED",
    )


@router.get(
    "/fraud/flags",
    response_model=list[FraudAuditItemOut],
    summary="List users flagged for suspicious step velocity or activity patterns",
)
async def list_fraud_flags(
    limit: int = Query(50, ge=1, le=200),
    session: AsyncSession = Depends(get_session),
) -> list[FraudAuditItemOut]:
    """Audit user activity metrics and return risk flags for anti-fraud review."""
    result = await session.execute(
        select(
            User,
            func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).label("lifetime_steps"),
            func.count(ActivityDaily.id).label("days_count"),
        )
        .outerjoin(ActivityDaily, User.id == ActivityDaily.user_id)
        .group_by(User.id)
        .order_by(func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).desc())
        .limit(limit)
    )
    rows = result.all()

    audit_items: list[FraudAuditItemOut] = []
    for user, lifetime_steps, days_count in rows:
        flags: list[str] = []
        risk_score = 0

        # Heuristic 1: Extremely high average steps per day (>= 18,000 steps/day)
        if days_count > 0 and (lifetime_steps / days_count) >= 18000:
            flags.append("HIGH_DAILY_AVERAGE_CADENCE")
            risk_score += 40

        # Heuristic 2: Suspended account
        if user.status == UserStatus.SUSPENDED:
            flags.append("MANUALLY_SUSPENDED")
            risk_score += 100

        audit_items.append(
            FraudAuditItemOut(
                user_id=user.id,
                email=user.email,
                status=user.status.value,
                total_lifetime_steps=int(lifetime_steps),
                days_recorded=int(days_count),
                risk_score=min(risk_score, 100),
                flags=flags,
            )
        )

    return audit_items


@router.post(
    "/users/{user_id}/status",
    summary="Update a user's account status (suspend, activate, delete)",
)
async def update_user_status(
    user_id: str,
    body: UpdateUserStatusIn,
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Administratively suspend, re-activate, or delete a user account."""
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.status = UserStatus(body.status)
    await session.commit()

    return {
        "user_id": user.id,
        "email": user.email,
        "status": user.status.value,
        "reason": body.reason,
        "message": f"User status updated to {user.status.value}",
    }
