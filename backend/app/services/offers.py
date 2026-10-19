"""Offer redemption business logic.

Correctness invariants (MVP_PLAN.md §1):
  - All-or-nothing: points are only deducted if the voucher is successfully
    issued.  If any check fails the transaction is rolled back.
  - Balance is computed inside the same transaction that deducts points, with
    a row-level lock on the user to serialise concurrent redeems.
  - Inventory is decremented atomically; a zero-inventory offer is blocked.
  - short_code uniqueness is enforced at the DB level (unique constraint);
    the generator retries on collision (vanishingly rare with 4^8 space).
"""
from __future__ import annotations

import hashlib
import json
import secrets
import string
import uuid
from dataclasses import asdict, dataclass
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException, status
from cryptography.fernet import Fernet, InvalidToken, MultiFernet
from sqlalchemy import or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings
from app.db.models import (
    LedgerReason,
    Offer,
    OfferStatus,
    PointsLedger,
    Partner,
    PartnerStatus,
    User,
    UserStatus,
    Voucher,
    VoucherStatus,
    RedemptionRequest,
)
from app.services.points import get_balance

# Characters used in short codes — no 0/O/I/1 to avoid misreading
_CODE_CHARS = "".join(
    c for c in (string.ascii_uppercase + string.digits)
    if c not in "0OI1"
)


def _generate_short_code() -> str:
    """Return a short code like SR-7K4Q-92MX."""
    part = lambda n: "".join(secrets.choice(_CODE_CHARS) for _ in range(n))  # noqa: E731
    return f"SR-{part(4)}-{part(4)}"


def _generate_token() -> tuple[str, str]:
    """Return (raw_token, token_hash).

    raw_token is sent to the client and embedded in the QR code.
    token_hash (SHA-256) is what we store — never the raw value.
    """
    raw = secrets.token_urlsafe(32)
    hashed = hashlib.sha256(raw.encode()).hexdigest()
    return raw, hashed


@dataclass
class RedeemResult:
    voucher_id: str
    short_code: str
    token: str          # raw token for QR
    expires_at: datetime
    points_spent: int
    balance: int        # post-spend balance
    is_replay: bool = False


def _receipt_cipher(settings: Settings) -> MultiFernet:
    try:
        return MultiFernet([Fernet(key.strip().encode()) for key in settings.redemption_receipt_keys.split(',') if key.strip()])
    except (ValueError, TypeError):
        raise HTTPException(status_code=503, detail='Reward purchase recovery is not configured') from None


def offer_claimed_by(user_id: str, offer_id):
    """Historical claims survive voucher expiry, cancellation and admin deletion."""
    return or_(
        select(PointsLedger.id).where(
            PointsLedger.user_id == user_id,
            PointsLedger.reason == LedgerReason.OFFER_SPEND,
            PointsLedger.ref_type == 'offer',
            PointsLedger.ref_id == offer_id,
        ).exists(),
        select(Voucher.id).where(
            Voucher.user_id == user_id, Voucher.offer_id == offer_id,
        ).exists(),
    )


async def redeem_offer(
    *,
    offer_id: str,
    user: User,
    session: AsyncSession,
    settings: Settings,
    request_key: str | None = None,
    expected_points_cost: int | None = None,
) -> RedeemResult:
    """Atomically spend points and issue a voucher.

    Steps (all inside one transaction):
      1. Lock the user row to serialise concurrent redeems.
      2. Fetch & validate the offer (status, date window, inventory).
      3. Check balance >= points_cost  →  402 if not.
      4. Append OFFER_SPEND ledger entry  (-points_cost).
      5. Decrement inventory if finite.
      6. Generate short_code + token; insert voucher row.
      7. Commit.
    """
    now = datetime.now(timezone.utc)
    cipher = _receipt_cipher(settings) if request_key else None

    # 1. Lock user row — serialises concurrent redeems for the same user
    authenticated_version = user.auth_version
    locked_user = await session.execute(
        select(User).where(User.id == user.id).with_for_update().execution_options(populate_existing=True)
    )
    user = locked_user.scalar_one()
    if user.status != UserStatus.ACTIVE or user.auth_version != authenticated_version:
        raise HTTPException(401, 'Account access changed. Please sign in again.')

    if request_key:
        receipt = (await session.execute(select(RedemptionRequest).where(
            RedemptionRequest.user_id == user.id,
            RedemptionRequest.request_key == request_key,
        ))).scalar_one_or_none()
        if receipt:
            if receipt.offer_id != offer_id:
                raise HTTPException(status_code=409, detail='Purchase ID was already used for another offer')
            try:
                data = json.loads(cipher.decrypt(receipt.response_ciphertext.encode()))
                data['expires_at'] = datetime.fromisoformat(data['expires_at'])
                data['is_replay'] = True
                if expected_points_cost is not None and data['points_spent'] != expected_points_cost:
                    raise HTTPException(status_code=409, detail='Purchase ID was already used with another points cost')
                return RedeemResult(**data)
            except (InvalidToken, ValueError, TypeError, KeyError):
                raise HTTPException(status_code=503, detail='Purchase already completed. Open Wallet while recovery is unavailable.') from None

    # 2. Fetch & validate offer
    offer_row = (await session.execute(
        select(Offer, offer_claimed_by(user.id, Offer.id))
        .where(Offer.id == offer_id).with_for_update(of=Offer)
    )).one_or_none()

    if offer_row is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    offer, already_claimed = offer_row

    # The user lock serialises distinct purchase IDs too. Retry recovery above
    # still returns the original receipt without creating another claim.
    if already_claimed:
        raise HTTPException(status_code=409, detail='You already claimed this reward. Each account can claim it once. Check My rewards for your voucher.')

    if offer.archived_at is not None or offer.status != OfferStatus.ACTIVE:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Offer is not active")
    partner = await session.get(Partner, offer.partner_id)
    if partner is None or partner.archived_at is not None or partner.status != PartnerStatus.ACTIVE:
        raise HTTPException(status_code=409, detail='Partner store is inactive')

    if offer.starts_at and offer.starts_at > now:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Offer has not started yet")

    if offer.ends_at and offer.ends_at < now:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Offer has expired")

    if offer.inventory is not None and offer.inventory <= 0:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Offer is out of stock")

    # 3. Check balance
    if expected_points_cost is not None and offer.points_cost != expected_points_cost:
        raise HTTPException(status_code=409, detail='Offer price changed. Refresh offers and review the points cost before redeeming again.')
    balance = await get_balance(user.id, session)
    if balance < offer.points_cost:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Insufficient points: need {offer.points_cost}, have {balance}",
        )

    # 4. Deduct points
    ledger = PointsLedger(
        id=str(uuid.uuid4()),
        user_id=user.id,
        delta=-offer.points_cost,
        reason=LedgerReason.OFFER_SPEND,
        ref_type="offer",
        ref_id=offer.id,
    )
    session.add(ledger)

    # 5. Decrement inventory
    if offer.inventory is not None:
        offer.inventory -= 1

    # 6. Generate voucher (retry on short_code collision)
    raw_token, token_hash = _generate_token()
    expires_at = now + timedelta(days=settings.voucher_validity_days)

    for attempt in range(5):
        short_code = _generate_short_code()
        voucher = Voucher(
            id=str(uuid.uuid4()),
            user_id=user.id,
            offer_id=offer.id,
            short_code=short_code,
            token_hash=token_hash,
            status=VoucherStatus.ISSUED,
            issued_at=now,
            expires_at=expires_at,
        )
        try:
            # A failed insert must roll back only the savepoint, not poison the
            # transaction containing the user's lock, inventory and points.
            async with session.begin_nested():
                session.add(voucher)
                await session.flush()
            break
        except IntegrityError as exc:
            if "uq_vouchers_short_code" in str(exc).lower() and attempt < 4:
                continue
            raise

    # 7. Commit everything atomically
    result = RedeemResult(
        voucher_id=voucher.id,
        short_code=short_code,
        token=raw_token,
        expires_at=expires_at,
        points_spent=offer.points_cost,
        balance=balance - offer.points_cost,
    )
    if request_key:
        session.add(RedemptionRequest(
            user_id=user.id, request_key=request_key, offer_id=offer_id,
            response_ciphertext=cipher.encrypt(json.dumps(asdict(result), default=lambda d: d.isoformat()).encode()).decode(),
        ))
    await session.commit()
    return result
