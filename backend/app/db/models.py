"""SQLAlchemy ORM models for all Qadam MVP tables (PostgreSQL).

Tables (§2 of MVP_PLAN.md):
    users, devices, activity_daily, points_ledger,
    partners, offers, vouchers, redemptions, audit_log

All tables use UUID PKs and carry a ``created_at`` timestamp.
Enum columns use Python enums mapped to VARCHAR so the DB stays schema-simple;
Postgres native ENUM types can be adopted post-MVP.
"""
from __future__ import annotations

import enum
import uuid
from datetime import datetime, timezone

# pyrefly: ignore [missing-import]
from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Enum,
    ForeignKey,
    Integer,
    Index,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    func,
)
# pyrefly: ignore [missing-import]
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class UserStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    SUSPENDED = "SUSPENDED"
    DELETED = "DELETED"


class LedgerReason(str, enum.Enum):
    STEP_EARN = "STEP_EARN"
    OFFER_SPEND = "OFFER_SPEND"
    ADJUST = "ADJUST"


class DiscountType(str, enum.Enum):
    PERCENT = "PERCENT"
    FIXED = "FIXED"
    FREE_ITEM = "FREE_ITEM"


class OfferStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    EXPIRED = "EXPIRED"


class PartnerStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"


class VoucherStatus(str, enum.Enum):
    ISSUED = "ISSUED"
    REDEEMED = "REDEEMED"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


# ---------------------------------------------------------------------------
# Models
# ---------------------------------------------------------------------------

class User(Base):
    """Registered app users."""
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(32), default="USER", nullable=False)
    partner_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("partners.id", ondelete="SET NULL"), nullable=True, index=True
    )
    status: Mapped[UserStatus] = mapped_column(
        Enum(UserStatus, name="user_status", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=UserStatus.ACTIVE,
    )
    country: Mapped[str | None] = mapped_column(String(2), nullable=True)
    timezone: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    devices: Mapped[list[Device]] = relationship(back_populates="user")
    activity_days: Mapped[list[ActivityDaily]] = relationship(back_populates="user")
    ledger_entries: Mapped[list[PointsLedger]] = relationship(back_populates="user")
    vouchers: Mapped[list[Voucher]] = relationship(back_populates="user")
    partner: Mapped[Partner | None] = relationship(back_populates="merchants", foreign_keys=[partner_id])


class Device(Base):
    """Registered devices (lightweight; attestation deferred)."""
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    platform: Mapped[str] = mapped_column(String(16), nullable=False)  # android | ios
    app_version: Mapped[str | None] = mapped_column(String(32), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="devices")


class ActivityDaily(Base):
    """One normalized row per user per local calendar day.

    Upserted on each sync; ``sync_key`` guarantees idempotency.
    """
    __tablename__ = "activity_daily"
    __table_args__ = (
        UniqueConstraint("user_id", "local_date", name="uq_activity_user_date"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    local_date: Mapped[str] = mapped_column(String(10), nullable=False)  # YYYY-MM-DD
    eligible_steps: Mapped[int] = mapped_column(BigInteger, nullable=False, default=0)
    source: Mapped[str] = mapped_column(String(32), nullable=False)  # health | manual
    sync_key: Mapped[str] = mapped_column(String(128), unique=True, nullable=False)
    sync_version: Mapped[int] = mapped_column(Integer, nullable=False, default=1)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="activity_days")


class PointsLedger(Base):
    """Append-only ledger. Balance = SUM(delta) for a user.

    Never update rows; only insert.
    """
    __tablename__ = "points_ledger"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    delta: Mapped[int] = mapped_column(Integer, nullable=False)  # positive = earn, negative = spend
    reason: Mapped[LedgerReason] = mapped_column(
        Enum(LedgerReason, name="ledger_reason", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    ref_type: Mapped[str | None] = mapped_column(String(64), nullable=True)   # e.g. "activity_daily"
    ref_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    campaign_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="ledger_entries")


class Partner(Base):
    """Merchant / brand partners."""
    __tablename__ = "partners"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    email: Mapped[str | None] = mapped_column(String(320), nullable=True)
    password_hash: Mapped[str | None] = mapped_column(String(255), nullable=True)
    category: Mapped[str | None] = mapped_column(String(64), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    location: Mapped[str | None] = mapped_column(String(255), nullable=True)
    api_key_hash: Mapped[str | None] = mapped_column(String(64), nullable=True, unique=True)
    status: Mapped[PartnerStatus] = mapped_column(
        Enum(PartnerStatus, name="partner_status", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=PartnerStatus.ACTIVE,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    offers: Mapped[list[Offer]] = relationship(back_populates="partner")
    merchants: Mapped[list[User]] = relationship(back_populates="partner", foreign_keys="User.partner_id")


class Offer(Base):
    """Redeemable offers from partners."""
    __tablename__ = "offers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    partner_id: Mapped[str] = mapped_column(ForeignKey("partners.id", ondelete="CASCADE"), nullable=False)
    title: Mapped[str] = mapped_column(String(256), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    discount_type: Mapped[DiscountType] = mapped_column(
        Enum(DiscountType, name="discount_type", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
    )
    discount_value: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    points_cost: Mapped[int] = mapped_column(Integer, nullable=False)
    min_basket: Mapped[float | None] = mapped_column(Numeric(10, 2), nullable=True)
    inventory: Mapped[int | None] = mapped_column(Integer, nullable=True)  # NULL = unlimited
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    status: Mapped[OfferStatus] = mapped_column(
        Enum(OfferStatus, name="offer_status", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=OfferStatus.ACTIVE,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    partner: Mapped[Partner] = relationship(back_populates="offers")
    vouchers: Mapped[list[Voucher]] = relationship(back_populates="offer")


class Voucher(Base):
    """Single-use voucher issued when a user spends points on an offer.

    ``token_hash`` stores a bcrypt/SHA-256 hash of the raw token sent to the
    app.  ``short_code`` is the human-readable merchant entry code.
    """
    __tablename__ = "vouchers"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    offer_id: Mapped[str] = mapped_column(ForeignKey("offers.id", ondelete="RESTRICT"), nullable=False)
    short_code: Mapped[str] = mapped_column(String(32), unique=True, nullable=False)
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[VoucherStatus] = mapped_column(
        Enum(VoucherStatus, name="voucher_status", values_callable=lambda x: [e.value for e in x]),
        nullable=False,
        default=VoucherStatus.ISSUED,
    )
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_now)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    redeemed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    user: Mapped[User] = relationship(back_populates="vouchers")
    offer: Mapped[Offer] = relationship(back_populates="vouchers")
    redemption: Mapped[Redemption | None] = relationship(back_populates="voucher", uselist=False)


class Redemption(Base):
    """Record of a voucher being redeemed at a merchant POS/API."""
    __tablename__ = "redemptions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    voucher_id: Mapped[str] = mapped_column(ForeignKey("vouchers.id", ondelete="RESTRICT"), unique=True, nullable=False)
    partner_id: Mapped[str] = mapped_column(ForeignKey("partners.id", ondelete="RESTRICT"), nullable=False)
    store_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    order_reference: Mapped[str | None] = mapped_column(String(256), nullable=True)
    discount_value: Mapped[float] = mapped_column(Numeric(10, 2), nullable=False)
    redeemed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=_now)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )

    voucher: Mapped[Voucher] = relationship(back_populates="redemption")


class AuditLog(Base):
    """Immutable audit trail for security-sensitive operations."""
    __tablename__ = "audit_log"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    actor: Mapped[str] = mapped_column(String(36), nullable=False)   # user_id or "system"
    action: Mapped[str] = mapped_column(String(128), nullable=False)
    object_type: Mapped[str] = mapped_column(String(64), nullable=False)
    object_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


class SupportTicket(Base):
    __tablename__ = 'support_tickets'
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), index=True)
    subject: Mapped[str] = mapped_column(String(120))
    category: Mapped[str] = mapped_column(String(24))
    status: Mapped[str] = mapped_column(String(16), default='OPEN', index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now, index=True)


class SupportMessage(Base):
    __tablename__ = 'support_messages'
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=_uuid)
    ticket_id: Mapped[str] = mapped_column(ForeignKey('support_tickets.id', ondelete='CASCADE'), index=True)
    author: Mapped[str] = mapped_column(String(16))
    body: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_now)


class SupportAISettings(Base):
    __tablename__ = 'support_ai_settings'
    id: Mapped[str] = mapped_column(String(16), primary_key=True, default='global')
    enabled: Mapped[bool] = mapped_column(Boolean, default=False)
    user_daily_limit: Mapped[int] = mapped_column(Integer, default=5)
    global_daily_limit: Mapped[int] = mapped_column(Integer, default=300)
    daily_token_budget: Mapped[int] = mapped_column(Integer, default=200000)


class SupportAIUsage(Base):
    __tablename__ = 'support_ai_usage'
    user_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    day: Mapped[str] = mapped_column(String(10), primary_key=True, index=True)
    requests: Mapped[int] = mapped_column(Integer, default=0)
    charged_tokens: Mapped[int] = mapped_column(Integer, default=0)
    input_tokens: Mapped[int] = mapped_column(Integer, default=0)
    output_tokens: Mapped[int] = mapped_column(Integer, default=0)
    last_request_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))


# Keep ORM-created test databases aligned with the production query indexes.
Index('ix_ledger_user_id', PointsLedger.user_id)
Index('ix_ledger_user_created', PointsLedger.user_id, PointsLedger.created_at.desc())
Index('ix_activity_date_user', ActivityDaily.local_date, ActivityDaily.user_id)
Index('ix_users_created_id', User.created_at.desc(), User.id)
Index('ix_vouchers_user_status', Voucher.user_id, Voucher.status)
Index('ix_vouchers_status_expiry', Voucher.status, Voucher.expires_at)
Index('ix_offers_partner', Offer.partner_id)
