"""Admin router for partner provisioning, key management, fraud auditing, analytics, and portal management."""
from __future__ import annotations

import secrets
import asyncio
import uuid
from datetime import date, datetime, timedelta, timezone
from typing import Any, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, status
from pydantic import AwareDatetime, BaseModel, EmailStr, Field, field_validator, model_validator
from sqlalchemy import delete, desc, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import joinedload, selectinload

from app.config import get_settings
from app.db.models import (
    ActivityDaily,
    AuditLog,
    Device,
    DiscountType,
    LedgerReason,
    Offer,
    OfferStatus,
    Partner,
    PartnerStatus,
    PointsLedger,
    Redemption,
    User,
    UserStatus,
    Voucher,
    VoucherStatus,
)
from app.db.postgres import get_session
from app.deps import get_current_admin
from app.services.partner_auth import hash_api_key
from app.services.security import create_access_token, hash_password
from app.services.email_verification import change_email
from app.services.device_binding import release_devices
from app.services.voucher_sweep import sweep_expired_vouchers
from app.services.local_date import local_today
from app.services.store_location import normalize_maps_url
from app.services.store_cover import MAX_COVER_BYTES, save_cover
from app.services.admin_lifecycle import offer_has_history, partner_has_history, user_has_history

public_router = APIRouter(prefix="/admin", tags=["admin"])
router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(get_current_admin)])


@router.get('/config', summary='Read active reward configuration')
async def reward_config() -> dict:
    settings = get_settings()
    return {
        'steps_per_point': settings.steps_per_point,
        'daily_step_cap': settings.daily_step_cap,
        'voucher_validity_days': settings.voucher_validity_days,
        'password_recovery_available': bool(settings.smtp_host and settings.smtp_from),
        'google_signin_configured': bool(settings.google_client_id),
        'environment': settings.environment,
    }


@router.post('/vouchers/sweep-expired', summary='Expire unused vouchers past their expiry')
async def sweep_vouchers(session: AsyncSession = Depends(get_session)) -> dict:
    result = await sweep_expired_vouchers(session)
    return {**result, 'message': 'Expired vouchers updated'}


@router.get('/fraud/flags', summary='Review high daily activity; flags are not proof of fraud')
async def fraud_flags(session: AsyncSession = Depends(get_session)) -> list[dict]:
    settings = get_settings()
    rows = (await session.execute(
        select(User.id, User.email, User.status, func.sum(ActivityDaily.eligible_steps), func.count(ActivityDaily.id))
        .join(ActivityDaily, ActivityDaily.user_id == User.id)
        .group_by(User.id, User.email, User.status)
        .having(func.avg(ActivityDaily.eligible_steps) >= settings.daily_step_cap * 0.9)
    )).all()
    return [dict(user_id=id, email=email, status=state.value, total_lifetime_steps=int(total),
                 days_recorded=days, risk_score=50, flags=['HIGH_DAILY_AVERAGE_CADENCE'])
            for id, email, state, total, days in rows]


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class AdminLoginIn(BaseModel):
    email: str
    password: str


class AdminUserStatusIn(BaseModel):
    status: Literal['ACTIVE', 'SUSPENDED', 'DELETED']


class AdminAdjustPointsIn(BaseModel):
    delta: int
    reason_note: str


class AdminPartnerIn(BaseModel):
    name: str = Field(min_length=2, max_length=128)
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    category: str | None = None
    description: str | None = None
    location: str | None = None
    google_maps_url: str | None = None
    status: PartnerStatus | None = PartnerStatus.ACTIVE
    generate_api_key: bool | None = False

    _maps_url = field_validator('google_maps_url')(normalize_maps_url)


class AdminPartnerPatchIn(BaseModel):
    name: str | None = None
    email: EmailStr | None = None
    category: str | None = None
    description: str | None = None
    location: str | None = None
    google_maps_url: str | None = None
    status: str | None = None

    _maps_url = field_validator('google_maps_url')(normalize_maps_url)


class AdminPartnerResetPasswordIn(BaseModel):
    password: str


class AdminOfferIn(BaseModel):
    partner_id: str
    title: str = Field(min_length=1, max_length=256)
    description: str | None = None
    discount_type: DiscountType
    discount_value: float = Field(ge=0, allow_inf_nan=False)
    points_cost: int = Field(ge=0)
    min_basket: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    inventory: int | None = Field(default=None, ge=0)
    starts_at: AwareDatetime | None = None
    ends_at: AwareDatetime | None = None
    status: OfferStatus | None = OfferStatus.ACTIVE

    @model_validator(mode='after')
    def valid_terms(self):
        if self.discount_type == DiscountType.PERCENT and self.discount_value > 100:
            raise ValueError('Percentage discount cannot exceed 100')
        if self.starts_at and self.ends_at and self.ends_at <= self.starts_at:
            raise ValueError('Offer end must follow its start')
        return self


class AdminOfferPatchIn(BaseModel):
    title: str | None = None
    description: str | None = None
    discount_type: DiscountType | None = None
    discount_value: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    points_cost: int | None = Field(default=None, ge=0)
    min_basket: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    inventory: int | None = Field(default=None, ge=0)
    status: OfferStatus | None = None


class AdminUserPatchIn(BaseModel):
    email: EmailStr | None = None
    role: str | None = None
    status: str | None = None


class AdminVoucherPatchIn(BaseModel):
    status: VoucherStatus | None = None


class AdminVoucherLookupIn(BaseModel):
    short_code: str


class AdminVoucherRedeemIn(BaseModel):
    short_code: str
    order_reference: str | None = None
    store_id: str | None = None


# ---------------------------------------------------------------------------
# 1. Admin Authentication
# ---------------------------------------------------------------------------

@public_router.post("/auth/login", summary="Admin Portal Login")
async def admin_login(body: AdminLoginIn) -> dict[str, Any]:
    settings = get_settings()
    if (
        body.email.strip().lower() != settings.admin_email.strip().lower()
        or body.password != settings.admin_password
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials",
        )

    token = create_access_token(
        subject="admin_user_root",
        extra_claims={"email": settings.admin_email, "role": "ADMIN"},
    )
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": "admin_user_root",
            "email": settings.admin_email,
            "role": "ADMIN",
        },
    }


@router.get("/auth/me", summary="Admin Profile")
async def admin_get_me() -> dict[str, Any]:
    settings = get_settings()
    return {
        "id": "admin_user_root",
        "email": settings.admin_email,
        "role": "ADMIN",
    }


# ---------------------------------------------------------------------------
# 2. Analytics Overview & Charts
# ---------------------------------------------------------------------------

@router.get("/analytics/overview", summary="Overview Metrics")
async def get_analytics_overview(session: AsyncSession = Depends(get_session)) -> dict[str, Any]:
    # Scalar subqueries preserve independent totals without a cartesian join.
    row = (await session.execute(select(
        select(func.count(User.id)).scalar_subquery(),
        select(func.coalesce(func.sum(ActivityDaily.eligible_steps), 0)).scalar_subquery(),
        select(func.count(Partner.id)).where(Partner.status == PartnerStatus.ACTIVE, Partner.archived_at.is_(None)).scalar_subquery(),
        select(func.count(Offer.id)).join(Partner).where(Offer.status == OfferStatus.ACTIVE,
            Offer.archived_at.is_(None), Partner.status == PartnerStatus.ACTIVE, Partner.archived_at.is_(None)).scalar_subquery(),
        select(func.count(Voucher.id)).scalar_subquery(),
        select(func.count(Voucher.id)).where(Voucher.status == VoucherStatus.REDEEMED).scalar_subquery(),
        select(func.coalesce(func.sum(Redemption.discount_value), 0)).scalar_subquery(),
    ))).one()
    total_users, total_steps, active_partners, active_offers, vouchers_issued, vouchers_redeemed, total_savings = row

    return {
        "total_users": total_users,
        "total_steps": int(total_steps),
        "active_partners": active_partners,
        "active_offers": active_offers,
        "vouchers_issued": vouchers_issued,
        "vouchers_redeemed": vouchers_redeemed,
        "total_customer_savings": float(total_savings),
    }


@router.get("/analytics/charts", summary="Chart Metrics")
async def get_analytics_charts(session: AsyncSession = Depends(get_session)) -> dict[str, Any]:
    # Recent daily steps aggregation
    steps_query = (
        select(
            ActivityDaily.local_date,
            func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).label("steps"),
        )
        .group_by(ActivityDaily.local_date)
        .order_by(desc(ActivityDaily.local_date))
        .limit(14)
    )
    steps_rows = (await session.execute(steps_query)).all()
    steps_data = [{"date": r.local_date, "steps": int(r.steps)} for r in reversed(steps_rows)]

    # Top partners by redemptions
    top_partners_q = (
        select(
            Partner.id,
            Partner.name,
            func.count(Redemption.id).label("count"),
            func.coalesce(func.sum(Redemption.discount_value), 0.0).label("value"),
        )
        .join(Redemption, Redemption.partner_id == Partner.id)
        .group_by(Partner.id, Partner.name)
        .order_by(desc("count"))
        .limit(5)
    )
    top_partners_res = (await session.execute(top_partners_q)).all()
    top_partners = [
        {"id": r.id, "name": r.name, "count": int(r.count), "value": float(r.value)}
        for r in top_partners_res
    ]

    # Top deals by redemptions
    top_deals_q = (
        select(
            Offer.id,
            Offer.title,
            func.count(Redemption.id).label("count"),
            func.coalesce(func.sum(Redemption.discount_value), 0.0).label("value"),
        )
        .join(Voucher, Voucher.id == Redemption.voucher_id)
        .join(Offer, Offer.id == Voucher.offer_id)
        .group_by(Offer.id, Offer.title)
        .order_by(desc("count"))
        .limit(5)
    )
    top_deals_res = (await session.execute(top_deals_q)).all()
    top_deals = [
        {"id": r.id, "title": r.title, "count": int(r.count), "value": float(r.value)}
        for r in top_deals_res
    ]

    return {
        "daily_steps": steps_data,
        "top_partners": top_partners,
        "top_deals": top_deals,
    }


# ---------------------------------------------------------------------------
# 3. Partner Management
# ---------------------------------------------------------------------------

@router.get("/partners", summary="List All Merchant Partners")
async def list_partners(
    search: str | None = None,
    status: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    offers = select(Offer.partner_id, func.count(Offer.id).label('count')).group_by(Offer.partner_id).subquery()
    redemptions = select(Redemption.partner_id, func.count(Redemption.id).label('count'),
        func.coalesce(func.sum(Redemption.discount_value), 0).label('value')).group_by(Redemption.partner_id).subquery()
    merchants = select(User.partner_id, func.min(User.email).label('email')).where(
        User.role == 'MERCHANT', User.partner_id.isnot(None)).group_by(User.partner_id).subquery()
    query = select(Partner, func.coalesce(offers.c.count, 0),
        func.coalesce(redemptions.c.count, 0), func.coalesce(redemptions.c.value, 0),
        merchants.c.email, ~partner_has_history(Partner.id)).outerjoin(offers, offers.c.partner_id == Partner.id).outerjoin(
        redemptions, redemptions.c.partner_id == Partner.id).outerjoin(
        merchants, merchants.c.partner_id == Partner.id).order_by(Partner.name)
    if status == 'ARCHIVED':
        query = query.where(Partner.archived_at.is_not(None))
    elif status and status != "ALL":
        query = query.where(Partner.status == PartnerStatus(status), Partner.archived_at.is_(None))
    if search:
        query = query.where(Partner.name.ilike(f"%{search}%"))

    result = await session.execute(query)
    partners = result.all()

    items = []
    for p, off_count, red_count, total_discount, merchant_email, can_delete in partners:
        email_val = merchant_email or p.email
        items.append({
            "id": p.id,
            "name": p.name,
            "email": email_val,
            "category": getattr(p, "category", None),
            "description": getattr(p, "description", None),
            "location": getattr(p, "location", None),
            "google_maps_url": getattr(p, "google_maps_url", None),
            "cover_image_url": p.cover_image_url,
            "archived_at": p.archived_at.isoformat() if p.archived_at else None,
            "can_delete": can_delete,
            "status": p.status.value,
            "has_api_key": bool(p.api_key_hash),
            "offer_count": off_count,
            "redemption_count": red_count,
            "total_discount_value": float(total_discount),
            "created_at": p.created_at.isoformat(),
        })
    return items


@router.post("/partners", status_code=status.HTTP_201_CREATED, summary="Create Partner")
async def create_partner(
    body: AdminPartnerIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    email_clean = str(body.email).strip().lower()

    # Check for existing user account with this email
    existing_user = (await session.execute(
        select(User).where(User.email == email_clean)
    )).scalar_one_or_none()
    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"An account with email '{email_clean}' already exists.",
        )

    raw_api_key = None
    api_key_hash = None
    if body.generate_api_key:
        raw_api_key = f"pk_live_{secrets.token_urlsafe(32)}"
        api_key_hash = hash_api_key(raw_api_key)

    hashed_pwd = hash_password(body.password)
    partner_id = str(uuid.uuid4())

    partner = Partner(
        id=partner_id,
        name=body.name.strip(),
        email=email_clean,
        password_hash=hashed_pwd,
        category=body.category.strip() if body.category else None,
        description=body.description.strip() if body.description else None,
        location=body.location.strip() if body.location else None,
        google_maps_url=body.google_maps_url.strip() if body.google_maps_url else None,
        api_key_hash=api_key_hash,
        status=PartnerStatus(body.status) if body.status else PartnerStatus.ACTIVE,
    )
    session.add(partner)

    # Create matching merchant user account for mobile app login
    merchant_user = User(
        id=str(uuid.uuid4()),
        email=email_clean,
        password_hash=hashed_pwd,
        role="MERCHANT",
        partner_id=partner_id,
        status=UserStatus.ACTIVE,
    )
    session.add(merchant_user)

    # Add audit log
    audit = AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="CREATE_PARTNER",
        object_type="PARTNER",
        object_id=partner.id,
    )
    session.add(audit)
    await session.commit()

    return {
        "id": partner.id,
        "name": partner.name,
        "email": email_clean,
        "category": partner.category,
        "description": partner.description,
        "location": partner.location,
        "google_maps_url": partner.google_maps_url,
        "status": partner.status.value,
        "raw_api_key": raw_api_key,
        "has_api_key": bool(partner.api_key_hash),
        "offer_count": 0,
        "redemption_count": 0,
        "total_discount_value": 0.0,
        "created_at": partner.created_at.isoformat(),
    }


@router.patch("/partners/{partner_id}", summary="Update Partner")
async def update_partner(
    partner_id: str,
    body: AdminPartnerPatchIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    partner = await session.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    if body.name is not None:
        partner.name = body.name.strip()
    if body.category is not None:
        partner.category = body.category.strip() if body.category else None
    if body.description is not None:
        partner.description = body.description.strip() if body.description else None
    if body.location is not None:
        partner.location = body.location.strip() if body.location else None
    if 'google_maps_url' in body.model_fields_set:
        partner.google_maps_url = body.google_maps_url.strip() if body.google_maps_url else None
    if body.status is not None:
        partner.status = PartnerStatus(body.status)

    if body.email is not None:
        email_clean = str(body.email).strip().lower()
        partner.email = email_clean
        # Also sync merchant user email
        merchant_user = (await session.execute(
            select(User).where(User.partner_id == partner_id).with_for_update()
        )).scalar_one_or_none()
        if merchant_user:
            existing = await session.scalar(select(User.id).where(User.email == email_clean, User.id != merchant_user.id))
            if existing:
                raise HTTPException(409, 'This email is already registered to another user.')
            change_email(merchant_user, email_clean)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="UPDATE_PARTNER",
        object_type="PARTNER",
        object_id=partner.id,
    ))
    await session.commit()
    return {
        "id": partner.id,
        "name": partner.name,
        "email": partner.email,
        "category": partner.category,
        "description": partner.description,
        "location": partner.location,
        "google_maps_url": partner.google_maps_url,
        "status": partner.status.value,
    }


async def _set_archived(model, record_id: str, archived: bool, session: AsyncSession, kind: str):
    record = await session.get(model, record_id, with_for_update=True)
    if record is None:
        raise HTTPException(404, f'{kind.title()} not found')
    if bool(record.archived_at) != archived:
        record.archived_at = datetime.now(timezone.utc) if archived else None
        session.add(AuditLog(actor='admin', action=f'{"ARCHIVE" if archived else "RESTORE"}_{kind}',
            object_type=kind, object_id=record_id))
        await session.commit()
    return {'id': record_id, 'archived_at': record.archived_at.isoformat() if record.archived_at else None}


@router.post('/partners/{partner_id}/archive', summary='Archive a store; retain issued vouchers')
async def archive_partner(partner_id: str, session: AsyncSession = Depends(get_session)):
    return await _set_archived(Partner, partner_id, True, session, 'PARTNER')


@router.post('/partners/{partner_id}/restore', summary='Restore an archived store')
async def restore_partner(partner_id: str, session: AsyncSession = Depends(get_session)):
    return await _set_archived(Partner, partner_id, False, session, 'PARTNER')


@router.post('/partners/{partner_id}/cover', summary='Upload a public store cover')
async def upload_partner_cover(partner_id: str, file: UploadFile, session: AsyncSession = Depends(get_session)):
    settings = get_settings()
    data = await file.read(MAX_COVER_BYTES + 1)
    url, image = await asyncio.to_thread(save_cover, data, settings)
    try:
        partner = await session.get(Partner, partner_id, with_for_update=True)
        if partner is None:
            raise HTTPException(404, 'Partner not found')
        partner.cover_image_url = url
        session.add(AuditLog(actor='admin', action='UPDATE_PARTNER_COVER', object_type='PARTNER', object_id=partner_id))
        await session.commit()
    except BaseException:
        await asyncio.to_thread(image.unlink, missing_ok=True)
        raise
    return {'id': partner_id, 'cover_image_url': url}


@router.delete('/partners/{partner_id}/cover', summary='Remove the current cover')
async def remove_partner_cover(partner_id: str, session: AsyncSession = Depends(get_session)):
    partner = await session.get(Partner, partner_id, with_for_update=True)
    if partner is None:
        raise HTTPException(404, 'Partner not found')
    partner.cover_image_url = None
    session.add(AuditLog(actor='admin', action='REMOVE_PARTNER_COVER', object_type='PARTNER', object_id=partner_id))
    await session.commit()
    # Versioned public files remain available to already-cached screens.
    return {'id': partner_id, 'cover_image_url': None}


@router.delete("/partners/{partner_id}", summary="Permanently delete an archived unused store")
async def delete_partner(
    partner_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    partner = await session.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    # Match purchase lock order: account, offers, then the partner. History is
    # checked only after in-flight purchases can finish, before any deletion.
    await session.execute(select(User).where(User.partner_id == partner_id).order_by(User.id).with_for_update())
    await session.execute(select(Offer).where(Offer.partner_id == partner_id).order_by(Offer.id).with_for_update())
    partner = (await session.execute(select(Partner).where(Partner.id == partner_id)
        .with_for_update().execution_options(populate_existing=True))).scalar_one_or_none()
    if not partner:
        raise HTTPException(404, 'Partner not found')
    if partner.archived_at is None:
        raise HTTPException(409, 'Archive this store before permanently deleting it.')
    if await session.scalar(select(partner_has_history(partner_id))):
        raise HTTPException(409, 'This store has customer or merchant history. Keep it archived to preserve points and vouchers.')

    # Find all offers for this partner
    offer_ids = (await session.execute(
        select(Offer.id).where(Offer.partner_id == partner_id)
    )).scalars().all()

    if offer_ids:
        voucher_ids = (await session.execute(
            select(Voucher.id).where(Voucher.offer_id.in_(offer_ids))
        )).scalars().all()

        if voucher_ids:
            await session.execute(
                delete(Redemption).where(Redemption.voucher_id.in_(voucher_ids))
            )
            await session.execute(
                delete(Voucher).where(Voucher.id.in_(voucher_ids))
            )

        await session.execute(
            delete(Offer).where(Offer.partner_id == partner_id)
        )

    await session.execute(
        delete(Redemption).where(Redemption.partner_id == partner_id)
    )

    await session.execute(
        delete(User).where(User.partner_id == partner_id, User.role == "MERCHANT")
    )

    await session.delete(partner)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="DELETE_PARTNER",
        object_type="PARTNER",
        object_id=partner_id,
    ))
    await session.commit()
    return {"message": f"Partner '{partner.name}' and associated offers, vouchers, and merchant accounts deleted successfully"}


@router.post("/partners/{partner_id}/reset-password", summary="Reset Partner Merchant Password")
async def reset_partner_password(
    partner_id: str,
    body: AdminPartnerResetPasswordIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    partner = await session.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    new_hash = hash_password(body.password)
    partner.password_hash = new_hash

    # Find or link merchant user
    merchant_user = (await session.execute(
        select(User).where(User.partner_id == partner_id)
    )).scalar_one_or_none()

    if merchant_user:
        merchant_user.password_hash = new_hash
        merchant_user.auth_version += 1
    elif partner.email:
        merchant_user = User(
            id=str(uuid.uuid4()),
            email=partner.email,
            password_hash=new_hash,
            role="MERCHANT",
            partner_id=partner_id,
            status=UserStatus.ACTIVE,
        )
        session.add(merchant_user)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="RESET_PARTNER_PASSWORD",
        object_type="PARTNER",
        object_id=partner.id,
    ))
    await session.commit()
    return {"partner_id": partner.id, "success": True, "message": "Merchant password reset successfully"}


@router.post("/partners/{partner_id}/regenerate-key", summary="Regenerate Partner API Key")
async def regenerate_partner_key(
    partner_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    partner = await session.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    raw_api_key = f"pk_live_{secrets.token_urlsafe(32)}"
    partner.api_key_hash = hash_api_key(raw_api_key)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="REGENERATE_API_KEY",
        object_type="PARTNER",
        object_id=partner.id,
    ))
    await session.commit()
    return {"partner_id": partner.id, "raw_api_key": raw_api_key}


@router.get("/partners/{partner_id}", summary="Get Partner Details")
async def get_partner(
    partner_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    merchant_email = select(func.min(User.email)).where(
        User.partner_id == partner_id, User.role == 'MERCHANT').scalar_subquery()
    row = (await session.execute(select(Partner, ~partner_has_history(Partner.id), merchant_email)
        .where(Partner.id == partner_id))).one_or_none()
    if row is None:
        raise HTTPException(status_code=404, detail="Partner not found")
    partner, can_delete, email = row
    email_val = email or partner.email

    # Fetch offers
    offers_res = await session.execute(
        select(Offer).where(Offer.partner_id == partner_id).order_by(desc(Offer.created_at))
    )
    offers = offers_res.scalars().all()

    # Fetch recent redemptions
    redemptions_res = await session.execute(
        select(Redemption)
        .options(joinedload(Redemption.voucher).joinedload(Voucher.offer))
        .where(Redemption.partner_id == partner_id)
        .order_by(desc(Redemption.redeemed_at))
        .limit(10)
    )
    redemptions = redemptions_res.scalars().all()

    return {
        "id": partner.id,
        "name": partner.name,
        "email": email_val,
        "category": getattr(partner, "category", None),
        "description": getattr(partner, "description", None),
        "location": getattr(partner, "location", None),
        "google_maps_url": getattr(partner, "google_maps_url", None),
        "cover_image_url": partner.cover_image_url,
        "archived_at": partner.archived_at.isoformat() if partner.archived_at else None,
        "can_delete": can_delete,
        "status": partner.status.value,
        "has_api_key": bool(partner.api_key_hash),
        "raw_api_key": None,
        "offers": [
            {
                "id": o.id,
                "title": o.title,
                "description": o.description,
                "discount_type": o.discount_type.value,
                "discount_value": float(o.discount_value),
                "points_cost": o.points_cost,
                "status": o.status.value,
                "archived_at": o.archived_at.isoformat() if o.archived_at else None,
            }
            for o in offers
        ],
        "recent_redemptions": [
            {
                "id": r.id,
                "short_code": r.voucher.short_code if r.voucher else "N/A",
                "offer_title": r.voucher.offer.title if (r.voucher and r.voucher.offer) else "Offer",
                "discount_value": float(r.discount_value),
                "redeemed_at": r.redeemed_at.isoformat(),
            }
            for r in redemptions
        ],
        "created_at": partner.created_at.isoformat(),
    }


# ---------------------------------------------------------------------------
# 4. Offers Management
# ---------------------------------------------------------------------------

@router.get("/offers", summary="List All Deals/Offers")
async def list_offers(
    partner_id: str | None = None,
    status: str | None = None,
    search: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(Offer, offer_has_history(Offer.id)).options(joinedload(Offer.partner)).order_by(desc(Offer.created_at))
    if partner_id and partner_id != "ALL":
        query = query.where(Offer.partner_id == partner_id)
    if status == 'ARCHIVED':
        query = query.where(Offer.archived_at.is_not(None))
    elif status and status != "ALL":
        query = query.where(Offer.status == OfferStatus(status), Offer.archived_at.is_(None))
    if search:
        query = query.where(Offer.title.ilike(f"%{search}%"))

    result = await session.execute(query)
    offers = result.all()

    items = []
    for o, has_history in offers:
        items.append({
            "id": o.id,
            "partner_id": o.partner_id,
            "partner_name": o.partner.name if o.partner else "Unknown",
            "partner_cover_image_url": o.partner.cover_image_url if o.partner else None,
            "partner_archived": bool(o.partner and o.partner.archived_at),
            "archived_at": o.archived_at.isoformat() if o.archived_at else None,
            "has_history": has_history,
            "can_delete": not has_history,
            "title": o.title,
            "description": o.description,
            "discount_type": o.discount_type.value,
            "discount_value": float(o.discount_value),
            "points_cost": o.points_cost,
            "min_basket": float(o.min_basket) if o.min_basket else None,
            "inventory": o.inventory,
            "status": o.status.value,
            "starts_at": o.starts_at.isoformat() if o.starts_at else None,
            "ends_at": o.ends_at.isoformat() if o.ends_at else None,
            "created_at": o.created_at.isoformat(),
        })
    return items


@router.post("/offers", status_code=status.HTTP_201_CREATED, summary="Create Offer")
async def create_offer(
    body: AdminOfferIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    partner = await session.get(Partner, body.partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")
    if partner.archived_at is not None:
        raise HTTPException(409, 'Restore this store before creating a new deal.')

    offer = Offer(
        id=str(uuid.uuid4()),
        partner_id=body.partner_id,
        title=body.title.strip(),
        description=body.description,
        discount_type=body.discount_type,
        discount_value=body.discount_value,
        points_cost=body.points_cost,
        min_basket=body.min_basket,
        inventory=body.inventory,
        starts_at=body.starts_at,
        ends_at=body.ends_at,
        status=body.status or OfferStatus.ACTIVE,
    )
    session.add(offer)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="CREATE_OFFER",
        object_type="OFFER",
        object_id=offer.id,
    ))
    await session.commit()
    return {"id": offer.id, "title": offer.title, "status": offer.status.value}


@router.patch("/offers/{offer_id}", summary="Update Offer")
async def update_offer(
    offer_id: str,
    body: AdminOfferPatchIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    offer = await session.get(Offer, offer_id, with_for_update=True)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    changed_terms = (
        (body.discount_type is not None and body.discount_type != offer.discount_type)
        or (body.discount_value is not None and body.discount_value != float(offer.discount_value))
        or ('min_basket' in body.model_fields_set and body.min_basket != (float(offer.min_basket) if offer.min_basket is not None else None))
    )
    if changed_terms and await session.scalar(select(offer_has_history(offer_id))):
        raise HTTPException(409, 'Customers have already claimed this deal. Create a new deal to change its discount or minimum spend; existing vouchers must keep their benefit.')

    discount_type = body.discount_type or offer.discount_type
    discount_value = body.discount_value if body.discount_value is not None else float(offer.discount_value)
    if discount_type == DiscountType.PERCENT and discount_value > 100:
        raise HTTPException(status_code=422, detail='Percentage discount cannot exceed 100')
    if body.title is not None:
        offer.title = body.title.strip()
    if body.description is not None:
        offer.description = body.description
    if body.discount_type is not None:
        offer.discount_type = body.discount_type
    if body.discount_value is not None:
        offer.discount_value = body.discount_value
    if body.points_cost is not None:
        offer.points_cost = body.points_cost
    if 'min_basket' in body.model_fields_set:
        offer.min_basket = body.min_basket
    if 'inventory' in body.model_fields_set:
        offer.inventory = body.inventory
    if body.status is not None:
        offer.status = body.status

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="UPDATE_OFFER",
        object_type="OFFER",
        object_id=offer.id,
    ))
    await session.commit()
    return {"id": offer.id, "title": offer.title, "status": offer.status.value}


@router.post('/offers/{offer_id}/archive', summary='Archive a deal; retain issued vouchers')
async def archive_offer(offer_id: str, session: AsyncSession = Depends(get_session)):
    return await _set_archived(Offer, offer_id, True, session, 'OFFER')


@router.post('/offers/{offer_id}/restore', summary='Restore an archived deal')
async def restore_offer(offer_id: str, session: AsyncSession = Depends(get_session)):
    return await _set_archived(Offer, offer_id, False, session, 'OFFER')


@router.delete("/offers/{offer_id}", summary="Permanently delete an archived unused deal")
async def delete_offer(
    offer_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    offer = await session.get(Offer, offer_id, with_for_update=True)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    if offer.archived_at is None:
        raise HTTPException(409, 'Archive this deal before permanently deleting it.')
    if await session.scalar(select(offer_has_history(offer_id))):
        raise HTTPException(409, 'This deal has purchase history. Keep it archived to preserve points and vouchers.')

    # Clean up associated vouchers and redemptions
    voucher_ids = (await session.execute(
        select(Voucher.id).where(Voucher.offer_id == offer_id)
    )).scalars().all()
    if voucher_ids:
        await session.execute(
            delete(Redemption).where(Redemption.voucher_id.in_(voucher_ids))
        )
        await session.execute(
            delete(Voucher).where(Voucher.id.in_(voucher_ids))
        )

    await session.delete(offer)
    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="DELETE_OFFER",
        object_type="OFFER",
        object_id=offer_id,
    ))
    await session.commit()
    return {"message": "Offer and associated vouchers deleted successfully"}


# ---------------------------------------------------------------------------
# 5. Voucher & POS Station
# ---------------------------------------------------------------------------

@router.get("/vouchers", summary="List Vouchers")
async def list_vouchers(
    partner_id: str | None = None,
    offer_id: str | None = None,
    status: str | None = None,
    short_code: str | None = None,
    search: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = (
        select(Voucher)
        .options(joinedload(Voucher.user), joinedload(Voucher.offer).joinedload(Offer.partner))
        .order_by(desc(Voucher.created_at))
    )
    if status and status != "ALL":
        query = query.where(Voucher.status == VoucherStatus(status))
    if short_code:
        query = query.where(Voucher.short_code.ilike(f"%{short_code}%"))
    if partner_id:
        query = query.where(Voucher.offer.has(Offer.partner_id == partner_id))
    if offer_id:
        query = query.where(Voucher.offer_id == offer_id)
    if search:
        pattern = f'%{search}%'
        query = query.where(or_(Voucher.short_code.ilike(pattern),
            Voucher.user.has(User.email.ilike(pattern)), Voucher.offer.has(Offer.title.ilike(pattern))))

    result = await session.execute(query)
    vouchers = result.scalars().all()

    items = []
    for v in vouchers:
        items.append({
            "id": v.id,
            "short_code": v.short_code,
            "user_email": v.user.email if v.user else "App User",
            "offer_title": v.offer.title if v.offer else "Deal",
            "partner_name": v.offer.partner.name if (v.offer and v.offer.partner) else "Store",
            "discount_type": v.offer.discount_type.value if v.offer else "PERCENT",
            "discount_value": float(v.offer.discount_value) if v.offer else 0.0,
            "status": v.status.value,
            "issued_at": v.issued_at.isoformat(),
            "expires_at": v.expires_at.isoformat(),
            "redeemed_at": v.redeemed_at.isoformat() if v.redeemed_at else None,
        })
    return items


@router.post("/vouchers/lookup", summary="Lookup Voucher for POS Validation")
async def lookup_voucher(
    body: AdminVoucherLookupIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    code = body.short_code.strip().upper()
    result = await session.execute(
        select(Voucher)
        .options(selectinload(Voucher.offer).selectinload(Offer.partner))
        .where(Voucher.short_code == code)
    )
    v = result.scalar_one_or_none()
    if not v:
        raise HTTPException(status_code=404, detail="Voucher code not found")

    is_expired = v.expires_at < datetime.now(timezone.utc)
    redeemable = v.status == VoucherStatus.ISSUED and not is_expired

    return {
        "id": v.id,
        "short_code": v.short_code,
        "status": v.status.value,
        "offer_title": v.offer.title if v.offer else "Deal",
        "partner_name": v.offer.partner.name if (v.offer and v.offer.partner) else "Store",
        "discount_type": v.offer.discount_type.value if v.offer else "PERCENT",
        "discount_value": float(v.offer.discount_value) if v.offer else 0.0,
        "redeemable": redeemable,
        "reason": "Ready to redeem" if redeemable else ("Expired" if is_expired else f"Already {v.status.value}"),
    }


@router.post("/vouchers/redeem", summary="Redeem Voucher at POS")
async def redeem_voucher(
    body: AdminVoucherRedeemIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    code = body.short_code.strip().upper()
    result = await session.execute(
        select(Voucher)
        .options(selectinload(Voucher.offer))
        .where(Voucher.short_code == code)
        .with_for_update()
    )
    v = result.scalar_one_or_none()
    if not v:
        raise HTTPException(status_code=404, detail="Voucher code not found")

    if v.status != VoucherStatus.ISSUED:
        raise HTTPException(status_code=400, detail=f"Voucher is already {v.status.value}")

    now = datetime.now(timezone.utc)
    if v.expires_at < now:
        v.status = VoucherStatus.EXPIRED
        await session.commit()
        raise HTTPException(status_code=400, detail="Voucher has expired")

    v.status = VoucherStatus.REDEEMED
    v.redeemed_at = now

    redemption = Redemption(
        id=str(uuid.uuid4()),
        voucher_id=v.id,
        partner_id=v.offer.partner_id,
        store_id=body.store_id or "MAIN_STORE",
        order_reference=body.order_reference or f"ORD-{secrets.token_hex(4).upper()}",
        discount_value=v.offer.discount_value,
        redeemed_at=now,
    )
    session.add(redemption)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="REDEEM_VOUCHER",
        object_type="VOUCHER",
        object_id=v.id,
    ))
    await session.commit()
    return {"message": "Voucher redeemed successfully", "short_code": v.short_code}


@router.patch("/vouchers/{voucher_id}", summary="Update Voucher Status")
async def update_voucher(
    voucher_id: str,
    body: AdminVoucherPatchIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    voucher = await session.get(Voucher, voucher_id, with_for_update=True)
    if not voucher:
        raise HTTPException(status_code=404, detail="Voucher not found")

    if body.status is not None:
        target = VoucherStatus(body.status.strip().upper())
        if target != voucher.status:
            if target != VoucherStatus.CANCELLED or voucher.status != VoucherStatus.ISSUED:
                raise HTTPException(409, 'Only an unused issued voucher can be cancelled. Use the checkout flow for redemption; used vouchers cannot be reactivated.')
            voucher.status = target

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="UPDATE_VOUCHER",
        object_type="VOUCHER",
        object_id=voucher_id,
    ))
    await session.commit()
    return {"id": voucher.id, "short_code": voucher.short_code, "status": voucher.status.value}


@router.delete("/vouchers/{voucher_id}", summary="Delete Voucher")
async def delete_voucher(
    voucher_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    voucher = await session.get(Voucher, voucher_id)
    if not voucher:
        raise HTTPException(status_code=404, detail="Voucher not found")

    raise HTTPException(409, 'Vouchers are purchase history and cannot be permanently deleted. Cancel an unused voucher instead.')

@router.get("/redemptions", summary="List Redemption History")
async def list_redemptions(
    partner_id: str | None = None,
    limit: int | None = Query(default=None, ge=1, le=1000),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = (
        select(Redemption)
        .options(
            joinedload(Redemption.voucher).joinedload(Voucher.user),
            joinedload(Redemption.voucher).joinedload(Voucher.offer).joinedload(Offer.partner),
        )
        .order_by(desc(Redemption.redeemed_at))
    )
    if partner_id:
        query = query.where(Redemption.partner_id == partner_id)
    if limit is not None:
        query = query.limit(limit)

    result = await session.execute(query)
    redemptions = result.scalars().all()

    items = []
    for r in redemptions:
        items.append({
            "id": r.id,
            "short_code": r.voucher.short_code if r.voucher else "—",
            "partner_name": r.voucher.offer.partner.name if (r.voucher and r.voucher.offer and r.voucher.offer.partner) else "Store",
            "offer_title": r.voucher.offer.title if (r.voucher and r.voucher.offer) else "Deal",
            "user_email": r.voucher.user.email if (r.voucher and r.voucher.user) else "Customer",
            "order_reference": r.order_reference or "—",
            "discount_value": float(r.discount_value),
            "redeemed_at": r.redeemed_at.isoformat(),
        })
    return items


# ---------------------------------------------------------------------------
# 6. User Directory & Step Management
# ---------------------------------------------------------------------------

@router.get("/users", summary="List App Users")
async def list_users(
    search: str | None = None,
    status: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    steps = select(ActivityDaily.user_id, func.sum(ActivityDaily.eligible_steps).label('total')).group_by(ActivityDaily.user_id).subquery()
    points = select(PointsLedger.user_id, func.sum(PointsLedger.delta).label('balance')).group_by(PointsLedger.user_id).subquery()
    query = (
        select(
            User,
            func.coalesce(steps.c.total, 0), func.coalesce(points.c.balance, 0), ~user_has_history(User.id),
        )
        .outerjoin(steps, User.id == steps.c.user_id)
        .outerjoin(points, User.id == points.c.user_id)
        .order_by(desc(User.created_at))
    )

    if status and status != "ALL":
        query = query.where(User.status == UserStatus(status))
    if search:
        query = query.where(User.email.ilike(f"%{search}%"))

    result = await session.execute(query)
    rows = result.all()

    items = []
    for u, total_steps, pts, can_delete in rows:
        items.append({
            "id": u.id,
            "email": u.email,
            "can_delete": can_delete,
            "role": u.role,
            "status": u.status.value,
            "total_steps": int(total_steps),
            "points_balance": int(pts),
            "country": u.country or "PK",
            "created_at": u.created_at.isoformat(),
        })
    return items


@router.patch("/users/{user_id}/status", summary="Update User Status")
async def update_user_status_patch(
    user_id: str,
    body: AdminUserStatusIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = await session.get(User, user_id, with_for_update=True)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    next_status = UserStatus(body.status)
    if next_status != user.status:
        user.status = next_status
        user.auth_version += 1
        if next_status == UserStatus.DELETED:
            await release_devices(user, session)
    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action=f"SET_USER_STATUS_{body.status}",
        object_type="USER",
        object_id=user.id,
    ))
    await session.commit()
    return {"user_id": user.id, "status": user.status.value}


@router.patch("/users/{user_id}", summary="Update User Details")
async def update_user(
    user_id: str,
    body: AdminUserPatchIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = await session.get(User, user_id, with_for_update=True)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    if body.email is not None:
        email_clean = str(body.email).strip().lower()
        existing = (await session.execute(
            select(User).where(User.email == email_clean, User.id != user_id)
        )).scalar_one_or_none()
        if existing:
            raise HTTPException(status_code=409, detail=f"Email '{email_clean}' is already registered to another user.")
        change_email(user, email_clean)

    if body.role is not None:
        user.role = body.role.strip().upper()

    if body.status is not None:
        next_status = UserStatus(body.status.strip().upper())
        if next_status != user.status:
            user.status = next_status
            user.auth_version += 1
            if next_status == UserStatus.DELETED:
                await release_devices(user, session)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="UPDATE_USER",
        object_type="USER",
        object_id=user.id,
    ))
    await session.commit()
    return {
        "id": user.id,
        "email": user.email,
        "role": user.role,
        "status": user.status.value,
    }


@router.delete("/users/{user_id}", summary="Delete User Account")
async def delete_user(
    user_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = await session.get(User, user_id, with_for_update=True)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.status != UserStatus.DELETED:
        raise HTTPException(409, 'Deactivate this account before permanently deleting it.')
    if await session.scalar(select(user_has_history(user_id))):
        raise HTTPException(409, 'This account has activity or purchase history. Keep it deactivated to preserve the records.')

    # Delete user's vouchers and associated redemptions
    v_ids = (await session.execute(
        select(Voucher.id).where(Voucher.user_id == user_id)
    )).scalars().all()
    if v_ids:
        await session.execute(
            delete(Redemption).where(Redemption.voucher_id.in_(v_ids))
        )
        await session.execute(
            delete(Voucher).where(Voucher.id.in_(v_ids))
        )

    # Delete ledger entries
    await session.execute(
        delete(PointsLedger).where(PointsLedger.user_id == user_id)
    )

    # Delete daily activity
    await session.execute(
        delete(ActivityDaily).where(ActivityDaily.user_id == user_id)
    )

    # Delete user devices
    await session.execute(
        delete(Device).where(Device.user_id == user_id)
    )

    # Delete user
    await session.delete(user)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="DELETE_USER",
        object_type="USER",
        object_id=user_id,
    ))
    await session.commit()
    return {"message": "User account and all associated activity deleted successfully"}


@router.post("/users/{user_id}/adjust-points", summary="Manual Points Adjustment")
async def adjust_user_points(
    user_id: str,
    body: AdminAdjustPointsIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = await session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    ledger_entry = PointsLedger(
        id=str(uuid.uuid4()),
        user_id=user.id,
        delta=body.delta,
        reason=LedgerReason.ADJUST,
        campaign_id=body.reason_note.strip(),
    )
    session.add(ledger_entry)

    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="MANUAL_POINTS_ADJUST",
        object_type="USER",
        object_id=user.id,
    ))
    await session.commit()

    # Get new balance
    new_bal = (await session.execute(
        select(func.coalesce(func.sum(PointsLedger.delta), 0)).where(PointsLedger.user_id == user.id)
    )).scalar_one() or 0

    return {"user_id": user.id, "delta": body.delta, "new_balance": int(new_bal)}


@router.get("/users/{user_id}/ledger", summary="Get User Points Ledger")
async def get_user_ledger(
    user_id: str,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    result = await session.execute(
        select(PointsLedger).where(PointsLedger.user_id == user_id).order_by(desc(PointsLedger.created_at))
    )
    entries = result.scalars().all()
    return [
        {
            "id": e.id,
            "delta": e.delta,
            "reason": e.reason.value,
            "campaign_id": e.campaign_id or e.ref_type or "Ledger Entry",
            "created_at": e.created_at.isoformat(),
        }
        for e in entries
    ]


@router.get("/users/{user_id}/activity", summary="User Historical Step Activity")
async def get_user_activity(
    user_id: str,
    range: str = Query(default="3months", pattern="^(today|week|month|3months|6months|year|all)$"),
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    today = local_today()
    if range == "today":
        start = today
    elif range == "week":
        start = today - timedelta(days=6)
    elif range == "month":
        start = today - timedelta(days=29)
    elif range == "3months":
        start = today - timedelta(days=90)
    elif range == "6months":
        start = today - timedelta(days=180)
    elif range == "year":
        start = today - timedelta(days=365)
    else:  # all
        start = None

    query = select(ActivityDaily).where(
        ActivityDaily.user_id == user_id,
        ActivityDaily.local_date <= today.isoformat(),
    )
    if start is not None:
        query = query.where(ActivityDaily.local_date >= start.isoformat())

    query = query.order_by(ActivityDaily.local_date)
    result = await session.execute(query)
    rows = result.scalars().all()

    days = [{"date": r.local_date, "eligible_steps": r.eligible_steps, "source": r.source} for r in rows]
    total_steps = sum(d["eligible_steps"] for d in days)
    return {"range": range, "total_steps": total_steps, "days": days}


# ---------------------------------------------------------------------------
# 7. Global Ledger & Audit Logs
# ---------------------------------------------------------------------------

@router.get("/ledger", summary="Global Points Ledger")
async def get_global_ledger(
    reason: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(PointsLedger).options(joinedload(PointsLedger.user)).order_by(desc(PointsLedger.created_at)).limit(100)
    if reason and reason != "ALL":
        query = query.where(PointsLedger.reason == LedgerReason(reason))

    result = await session.execute(query)
    entries = result.scalars().all()
    return [
        {
            "id": e.id,
            "user_email": e.user.email if e.user else e.user_id,
            "delta": e.delta,
            "reason": e.reason.value,
            "campaign_id": e.campaign_id or e.ref_type or "System Entry",
            "created_at": e.created_at.isoformat(),
        }
        for e in entries
    ]


@router.get("/audit-logs", summary="System Audit Logs")
async def list_audit_logs(
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    result = await session.execute(
        select(AuditLog).order_by(desc(AuditLog.created_at)).limit(100)
    )
    logs = result.scalars().all()
    return [
        {
            "id": l.id,
            "actor": l.actor,
            "action": l.action,
            "object_type": l.object_type,
            "object_id": l.object_id,
            "created_at": l.created_at.isoformat(),
        }
        for l in logs
    ]
