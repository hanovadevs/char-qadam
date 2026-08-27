"""Admin router for partner provisioning, key management, and operational maintenance."""
from __future__ import annotations

import secrets
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Partner, PartnerStatus
from app.db.postgres import get_session
from app.schemas.admin import CreatePartnerIn, CreatePartnerOut, SweepExpiredOut
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
