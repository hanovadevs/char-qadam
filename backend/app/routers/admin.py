"""Admin router for partner provisioning, key management, fraud auditing, analytics, and portal management."""
from __future__ import annotations

import secrets
import hmac
import uuid
from datetime import datetime, timezone
from typing import Any

from starlette.concurrency import run_in_threadpool
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, EmailStr, Field, field_validator
from sqlalchemy import case, delete, desc, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.config import get_settings
from app.db.models import (
    ActivityDaily,
    AuditLog,
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
from app.services.partner_auth import hash_api_key
from app.services.security import create_access_token, hash_password
from app.schemas.auth import PasswordInput
from app.services.voucher_sweep import sweep_expired_vouchers

from app.deps import require_admin

router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_admin)])
auth_router = APIRouter(prefix="/admin", tags=["admin"])



# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class AdminLoginIn(BaseModel):
    email: str
    password: str = Field(min_length=8, max_length=72)


class AdminUserStatusIn(BaseModel):
    status: str = Field(pattern="^(ACTIVE|SUSPENDED|DELETED)$")


class AdminAdjustPointsIn(BaseModel):
    delta: int = Field(ge=-1000000, le=1000000)
    reason_note: str = Field(min_length=3, max_length=64)

    @field_validator("reason_note")
    @classmethod
    def reason_required(cls, value):
        if len(value.strip()) < 3:
            raise ValueError("A meaningful adjustment reason is required")
        return value.strip()

    @field_validator("delta")
    @classmethod
    def nonzero_delta(cls, value):
        if value == 0:
            raise ValueError("Adjustment must be nonzero")
        return value


class AdminPartnerIn(PasswordInput):
    name: str
    email: EmailStr
    password: str = Field(min_length=8, max_length=72)
    category: str | None = None
    description: str | None = None
    location: str | None = None
    status: str | None = Field(default="ACTIVE", pattern="^(ACTIVE|INACTIVE)$")
    generate_api_key: bool | None = False


class AdminPartnerPatchIn(BaseModel):
    name: str | None = None
    email: EmailStr | None = None
    category: str | None = None
    description: str | None = None
    location: str | None = None
    status: str | None = Field(default=None, pattern="^(ACTIVE|INACTIVE)$")


class AdminPartnerResetPasswordIn(PasswordInput):
    password: str = Field(min_length=8, max_length=72)


class AdminOfferIn(BaseModel):
    partner_id: str
    title: str
    description: str | None = None
    discount_type: DiscountType
    discount_value: float = Field(ge=0, allow_inf_nan=False)
    points_cost: int = Field(ge=1)
    min_basket: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    inventory: int | None = Field(default=None, ge=0)
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    status: OfferStatus | None = OfferStatus.ACTIVE


class AdminOfferPatchIn(BaseModel):
    title: str | None = None
    description: str | None = None
    discount_type: DiscountType | None = None
    discount_value: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    points_cost: int | None = Field(default=None, ge=1)
    min_basket: float | None = Field(default=None, ge=0, allow_inf_nan=False)
    inventory: int | None = Field(default=None, ge=0)
    status: OfferStatus | None = None


class AdminVoucherLookupIn(BaseModel):
    short_code: str


class AdminVoucherRedeemIn(BaseModel):
    short_code: str
    order_reference: str | None = None
    store_id: str | None = None


# ---------------------------------------------------------------------------
# 1. Admin Authentication
# ---------------------------------------------------------------------------

@auth_router.post("/auth/login", summary="Admin Portal Login")
async def admin_login(body: AdminLoginIn) -> dict[str, Any]:
    settings = get_settings()
    if (
        body.email.strip().lower() != settings.admin_email.strip().lower()
        or not hmac.compare_digest(body.password.encode(), settings.admin_password.encode())
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials",
        )

    token = create_access_token(
        subject="admin_user_root",
        expires_minutes=60,
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
    # Independent scalar aggregates in one database round trip, without joins
    # that would multiply counts across unrelated tables.
    metrics = (await session.execute(select(
        select(func.count(User.id)).scalar_subquery().label("total_users"),
        select(func.coalesce(func.sum(ActivityDaily.eligible_steps), 0)).scalar_subquery().label("total_steps"),
        select(func.count(Partner.id)).where(Partner.status == PartnerStatus.ACTIVE).scalar_subquery().label("active_partners"),
        select(func.count(Offer.id)).where(Offer.status == OfferStatus.ACTIVE).scalar_subquery().label("active_offers"),
        select(func.count(Voucher.id)).scalar_subquery().label("vouchers_issued"),
        select(func.count(Voucher.id)).where(Voucher.status == VoucherStatus.REDEEMED).scalar_subquery().label("vouchers_redeemed"),
        select(func.coalesce(func.sum(Redemption.discount_value), 0)).select_from(Redemption).join(Voucher, Voucher.id == Redemption.voucher_id).join(Offer, Offer.id == Voucher.offer_id).where(Offer.discount_type == DiscountType.FIXED).scalar_subquery().label("fixed_discount_value"),
    ))).mappings().one()
    return {key: float(value) if key == "fixed_discount_value" else int(value) for key, value in metrics.items()}



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
            func.coalesce(func.sum(case((Offer.discount_type == DiscountType.FIXED, Redemption.discount_value), else_=0)), 0.0).label("value"),
        )
        .join(Redemption, Redemption.partner_id == Partner.id)
        .join(Voucher, Voucher.id == Redemption.voucher_id)
        .join(Offer, Offer.id == Voucher.offer_id)
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
            func.coalesce(func.sum(case((Offer.discount_type == DiscountType.FIXED, Redemption.discount_value), else_=0)), 0.0).label("value"),
        )
        .select_from(Redemption)
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
    status: str | None = Query(default=None, pattern="^(ALL|ACTIVE|INACTIVE)$"),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(Partner).order_by(Partner.name)
    if status and status != "ALL":
        query = query.where(Partner.status == PartnerStatus(status))
    if search:
        query = query.where(Partner.name.ilike(f"%{search}%"))

    result = await session.execute(query)
    partners = result.scalars().all()

    # Aggregate offer counts per partner
    offer_counts_res = await session.execute(
        select(Offer.partner_id, func.count(Offer.id)).group_by(Offer.partner_id)
    )
    offer_counts = dict(offer_counts_res.all())

    # Aggregate redemption counts and discount totals per partner
    redemption_stats_res = await session.execute(
        select(
            Redemption.partner_id,
            func.count(Redemption.id),
            func.coalesce(func.sum(case((Offer.discount_type == DiscountType.FIXED, Redemption.discount_value), else_=0)), 0.0),
        ).select_from(Redemption).join(Voucher, Voucher.id == Redemption.voucher_id).join(Offer, Offer.id == Voucher.offer_id).group_by(Redemption.partner_id)
    )
    redemption_stats = {
        row[0]: (int(row[1]), float(row[2]))
        for row in redemption_stats_res.all()
    }

    # Fetch merchant users mapping
    merchant_users_res = await session.execute(
        select(User.partner_id, User.email).where(User.role == "MERCHANT", User.partner_id.isnot(None))
    )
    merchant_emails = dict(merchant_users_res.all())

    items = []
    for p in partners:
        off_count = offer_counts.get(p.id, 0)
        red_count, total_discount = redemption_stats.get(p.id, (0, 0.0))
        email_val = merchant_emails.get(p.id) or p.email
        items.append({
            "id": p.id,
            "name": p.name,
            "email": email_val,
            "category": getattr(p, "category", None),
            "description": getattr(p, "description", None),
            "location": getattr(p, "location", None),
            "status": p.status.value,
            "has_api_key": bool(p.api_key_hash),
            "offer_count": off_count,
            "redemption_count": red_count,
            "total_discount_value": total_discount,
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

    hashed_pwd = await run_in_threadpool(hash_password, body.password)
    partner_id = str(uuid.uuid4())

    partner = Partner(
        id=partner_id,
        name=body.name.strip(),
        email=email_clean,
        password_hash=hashed_pwd,
        category=body.category.strip() if body.category else None,
        description=body.description.strip() if body.description else None,
        location=body.location.strip() if body.location else None,
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
    if body.status is not None:
        partner.status = PartnerStatus(body.status)

    if body.email is not None:
        email_clean = str(body.email).strip().lower()
        partner.email = email_clean
        # Also sync merchant user email
        merchant_user = (await session.execute(
            select(User).where(User.partner_id == partner_id)
        )).scalar_one_or_none()
        if merchant_user:
            merchant_user.email = email_clean

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
        "status": partner.status.value,
    }


@router.post("/partners/{partner_id}/reset-password", summary="Reset Partner Merchant Password")
async def reset_partner_password(
    partner_id: str,
    body: AdminPartnerResetPasswordIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    partner = await session.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    new_hash = await run_in_threadpool(hash_password, body.password)
    partner.password_hash = new_hash

    # Find or link merchant user
    merchant_user = (await session.execute(
        select(User).where(User.partner_id == partner_id)
    )).scalar_one_or_none()

    if merchant_user:
        merchant_user.password_hash = new_hash
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
    partner = await session.get(Partner, partner_id)
    if not partner:
        raise HTTPException(status_code=404, detail="Partner not found")

    # Fetch merchant user email if any
    merchant_user = (await session.execute(
        select(User).where(User.partner_id == partner_id)
    )).scalar_one_or_none()
    email_val = merchant_user.email if merchant_user else partner.email

    # Fetch offers
    offers_res = await session.execute(
        select(Offer).where(Offer.partner_id == partner_id).order_by(desc(Offer.created_at))
    )
    offers = offers_res.scalars().all()

    # Fetch recent redemptions
    redemptions_res = await session.execute(
        select(Redemption)
        .options(selectinload(Redemption.voucher).selectinload(Voucher.offer))
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
    status: str | None = Query(default=None, pattern="^(ALL|ACTIVE|INACTIVE|EXPIRED)$"),
    search: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(Offer).options(selectinload(Offer.partner)).order_by(desc(Offer.created_at))
    if partner_id and partner_id != "ALL":
        query = query.where(Offer.partner_id == partner_id)
    if status and status != "ALL":
        query = query.where(Offer.status == OfferStatus(status))
    if search:
        query = query.where(Offer.title.ilike(f"%{search}%"))

    result = await session.execute(query)
    offers = result.scalars().all()

    items = []
    for o in offers:
        items.append({
            "id": o.id,
            "partner_id": o.partner_id,
            "partner_name": o.partner.name if o.partner else "Unknown",
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
    offer = await session.get(Offer, offer_id)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

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
    if body.min_basket is not None:
        offer.min_basket = body.min_basket
    if body.inventory is not None:
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


@router.delete("/offers/{offer_id}", summary="Delete Offer")
async def delete_offer(
    offer_id: str,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    offer = await session.get(Offer, offer_id)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    await session.delete(offer)
    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action="DELETE_OFFER",
        object_type="OFFER",
        object_id=offer_id,
    ))
    await session.commit()
    return {"message": "Offer deleted successfully"}


# ---------------------------------------------------------------------------
# 5. Voucher & POS Station
# ---------------------------------------------------------------------------

@router.get("/vouchers", summary="List Vouchers")
async def list_vouchers(
    partner_id: str | None = None,
    offer_id: str | None = None,
    status: str | None = Query(default=None, pattern="^(ALL|ISSUED|REDEEMED|EXPIRED|CANCELLED)$"),
    short_code: str | None = None,
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = (
        select(Voucher)
        .options(selectinload(Voucher.user), selectinload(Voucher.offer).selectinload(Offer.partner))
        .order_by(desc(Voucher.created_at))
    )
    if status and status != "ALL":
        query = query.where(Voucher.status == VoucherStatus(status))
    if partner_id:
        query = query.where(Voucher.offer.has(Offer.partner_id == partner_id))
    if offer_id:
        query = query.where(Voucher.offer_id == offer_id)
    if short_code:
        query = query.where(Voucher.short_code.ilike(f"%{short_code}%"))

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


@router.get("/redemptions", summary="List Redemption History")
async def list_redemptions(
    partner_id: str | None = None,
    limit: int = Query(default=100, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = (
        select(Redemption)
        .options(
            selectinload(Redemption.voucher).selectinload(Voucher.user),
            selectinload(Redemption.voucher).selectinload(Voucher.offer).selectinload(Offer.partner),
        )
        .order_by(desc(Redemption.redeemed_at))
    )
    if partner_id:
        query = query.where(Redemption.partner_id == partner_id)

    result = await session.execute(query.limit(limit).offset(offset))
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
    status: str | None = Query(default=None, pattern="^(ALL|ACTIVE|SUSPENDED|DELETED)$"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = (
        select(
            User,
            func.coalesce(func.sum(ActivityDaily.eligible_steps), 0).label("total_steps"),
        )
        .outerjoin(ActivityDaily, User.id == ActivityDaily.user_id)
        .group_by(User.id)
        .order_by(desc(User.created_at), User.id)
    )

    if status and status != "ALL":
        query = query.where(User.status == UserStatus(status))
    if search:
        query = query.where(User.email.ilike(f"%{search}%"))

    result = await session.execute(query.limit(limit).offset(offset))
    rows = result.all()

    user_ids = [u.id for u, _ in rows]
    balances = dict((await session.execute(
        select(PointsLedger.user_id, func.sum(PointsLedger.delta))
        .where(PointsLedger.user_id.in_(user_ids))
        .group_by(PointsLedger.user_id)
    )).all()) if user_ids else {}
    items = []
    for u, total_steps in rows:
        pts = balances.get(u.id, 0)

        items.append({
            "id": u.id,
            "email": u.email,
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
    user = await session.get(User, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user.status = UserStatus(body.status)
    session.add(AuditLog(
        id=str(uuid.uuid4()),
        actor="admin",
        action=f"SET_USER_STATUS_{body.status}",
        object_type="USER",
        object_id=user.id,
    ))
    await session.commit()
    return {"user_id": user.id, "status": user.status.value}


@router.post("/users/{user_id}/adjust-points", summary="Manual Points Adjustment")
async def adjust_user_points(
    user_id: str,
    body: AdminAdjustPointsIn,
    session: AsyncSession = Depends(get_session),
) -> dict[str, Any]:
    user = (await session.execute(select(User).where(User.id == user_id).with_for_update())).scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    from app.services.points import get_balance
    balance = await get_balance(user_id, session)
    if balance + body.delta < 0:
        raise HTTPException(status_code=409, detail="Adjustment would make the user's balance negative")
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


# ---------------------------------------------------------------------------
# 7. Global Ledger & Audit Logs
# ---------------------------------------------------------------------------

@router.get("/ledger", summary="Global Points Ledger")
async def get_global_ledger(
    reason: str | None = Query(default=None, pattern="^(ALL|STEP_EARN|OFFER_SPEND|ADJUST)$"),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(PointsLedger).options(selectinload(PointsLedger.user)).order_by(desc(PointsLedger.created_at), PointsLedger.id).limit(limit).offset(offset)
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
    action: str | None = Query(default=None, max_length=128),
    actor: str | None = Query(default=None, max_length=36),
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    session: AsyncSession = Depends(get_session),
) -> list[dict[str, Any]]:
    query = select(AuditLog).order_by(desc(AuditLog.created_at), AuditLog.id)
    if action:
        query = query.where(AuditLog.action.ilike(f"%{action}%"))
    if actor:
        query = query.where(AuditLog.actor == actor)
    result = await session.execute(query.limit(limit).offset(offset))
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


@router.get("/system", summary="Live operational status and rewards configuration")
async def system_status(session: AsyncSession = Depends(get_session)):
    import time
    from sqlalchemy import text
    settings = get_settings()
    started = time.perf_counter()
    await session.execute(text("SELECT 1"))
    latency = round((time.perf_counter() - started) * 1000, 2)
    now = datetime.now(timezone.utc)
    counts = (await session.execute(select(
        select(func.count(Voucher.id)).where(Voucher.status == VoucherStatus.ISSUED, Voucher.expires_at < now).scalar_subquery().label("overdue_vouchers"),
        select(func.count(Offer.id)).where(Offer.status == OfferStatus.ACTIVE, Offer.inventory <= 10).scalar_subquery().label("low_inventory_offers"),
        select(func.count(Offer.id)).where(Offer.status == OfferStatus.ACTIVE, Offer.ends_at < now).scalar_subquery().label("ended_active_offers"),
    ))).mappings().one()
    return {
        "environment": settings.environment,
        "database": {"status": "connected", "latency_ms": latency},
        "rewards": {"steps_per_point": settings.steps_per_point, "daily_step_cap": settings.daily_step_cap,
                    "voucher_validity_days": settings.voucher_validity_days},
        "attention": dict(counts),
        "checked_at": now.isoformat(),
    }


@router.post("/vouchers/sweep-expired", summary="Expire overdue vouchers")
async def expire_overdue_vouchers(session: AsyncSession = Depends(get_session)):
    # Voucher updates and audit record must commit together.
    now = datetime.now(timezone.utc)
    result = await session.execute(update(Voucher).where(
        Voucher.status == VoucherStatus.ISSUED, Voucher.expires_at < now,
    ).values(status=VoucherStatus.EXPIRED).returning(Voucher.id))
    count = len(result.all())
    session.add(AuditLog(actor="admin", action="SWEEP_EXPIRED_VOUCHERS", object_type="VOUCHER"))
    await session.commit()
    return {"swept_count": count}


@router.get("/ledger/summary", summary="All-time points totals independent of the visible page")
async def ledger_summary(session: AsyncSession = Depends(get_session)):
    row = (await session.execute(select(
        func.coalesce(func.sum(case((PointsLedger.delta > 0, PointsLedger.delta), else_=0)), 0),
        func.coalesce(func.sum(case((PointsLedger.delta < 0, -PointsLedger.delta), else_=0)), 0),
        func.coalesce(func.sum(PointsLedger.delta), 0),
    ))).one()
    return {"credited": int(row[0]), "debited": int(row[1]), "balance": int(row[2])}
