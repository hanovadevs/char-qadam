"""Private generated store ledgers and durable generation history."""
import asyncio
import hashlib
import uuid
from datetime import date, datetime, timezone
from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Response
from pydantic import BaseModel, Field
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.models import AuditLog, MerchantLedger, Offer, Partner, Redemption, Voucher
from app.db.postgres import get_session
from app.deps import get_current_partner
from app.services.merchant_ledger import (PAKISTAN, MAX_LEDGER_ROWS, LedgerEntry, fixed_total,
    ledger_path, period_bounds, render_ledger, save_ledger, utc_boundaries)

router = APIRouter(prefix='/partner/v1/ledgers', tags=['partner'])


class GenerateLedgerIn(BaseModel):
    period: Literal['week', 'month']
    anchor_date: date = Field(ge=date(2020, 1, 1))
    request_id: uuid.UUID


class MerchantLedgerOut(BaseModel):
    id: str
    period: str
    starts_on: str
    ends_on: str
    timezone: str
    row_count: int
    fixed_discount_total: Decimal
    created_at: datetime

    model_config = {'from_attributes': True}


@router.get('', response_model=list[MerchantLedgerOut])
async def history(limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
                  partner: Partner = Depends(get_current_partner), session: AsyncSession = Depends(get_session)):
    return (await session.scalars(select(MerchantLedger).where(MerchantLedger.partner_id == partner.id)
        .order_by(MerchantLedger.created_at.desc(), MerchantLedger.id.desc()).limit(limit).offset(offset))).all()


@router.post('', response_model=MerchantLedgerOut, status_code=201)
async def generate(body: GenerateLedgerIn, partner: Partner = Depends(get_current_partner),
                   session: AsyncSession = Depends(get_session)):
    now = datetime.now(timezone.utc)
    if body.anchor_date > now.astimezone(PAKISTAN).date():
        raise HTTPException(422, 'Choose today or an earlier date.')
    first, last = period_bounds(body.period, body.anchor_date)
    # Bound generation per store and serialize retries of the same request.
    await session.scalar(select(Partner).where(Partner.id == partner.id).with_for_update())
    prior = await session.scalar(select(MerchantLedger).where(MerchantLedger.partner_id == partner.id,
        MerchantLedger.request_id == str(body.request_id)))
    if prior:
        if (prior.period, prior.starts_on, prior.ends_on) != (body.period, first.isoformat(), last.isoformat()):
            raise HTTPException(409, 'This generation request already belongs to a different period.')
        return prior
    day_start, _ = utc_boundaries(now.astimezone(PAKISTAN).date(), now.astimezone(PAKISTAN).date())
    generated_today = await session.scalar(select(func.count()).select_from(MerchantLedger).where(
        MerchantLedger.partner_id == partner.id, MerchantLedger.created_at >= day_start))
    if generated_today >= 100:
        raise HTTPException(429, 'The daily report limit is reached. Download an existing ledger from history.')
    start, end = utc_boundaries(first, last)
    records = (await session.execute(select(Redemption, Voucher.short_code, Offer.title, Offer.discount_type)
        .join(Voucher, Redemption.voucher_id == Voucher.id).join(Offer, Voucher.offer_id == Offer.id)
        .where(Redemption.partner_id == partner.id, Redemption.redeemed_at >= start,
            Redemption.redeemed_at < end, Redemption.redeemed_at <= now)
        .order_by(Redemption.redeemed_at, Redemption.id).limit(MAX_LEDGER_ROWS + 1))).all()
    if len(records) > MAX_LEDGER_ROWS:
        raise HTTPException(413, 'This period has too many redemptions for one PDF. Choose a week instead of a month or contact support.')
    entries = [LedgerEntry(red.redeemed_at, code, title, kind.value, Decimal(str(red.discount_value)),
                           red.store_id, red.order_reference) for red, code, title, kind in records]
    report_id = str(uuid.uuid4())
    data = await asyncio.to_thread(render_ledger, store_name=partner.name, report_id=report_id,
        period=body.period, first=first, last=last, generated_at=now, entries=entries)
    settings = get_settings()
    checksum = await asyncio.to_thread(save_ledger, data, report_id, settings)
    report = MerchantLedger(id=report_id, partner_id=partner.id, request_id=str(body.request_id),
        period=body.period, starts_on=first.isoformat(), ends_on=last.isoformat(), timezone='Asia/Karachi',
        row_count=len(entries), fixed_discount_total=fixed_total(entries), sha256=checksum, created_at=now)
    session.add(report)
    session.add(AuditLog(id=str(uuid.uuid4()), actor=partner.id, action='GENERATE_MERCHANT_LEDGER',
        object_type='MERCHANT_LEDGER', object_id=report_id))
    try:
        await session.commit()
    except Exception:
        ledger_path(report_id, settings).unlink(missing_ok=True)
        raise
    return report


@router.get('/{report_id}/pdf')
async def download(report_id: uuid.UUID, partner: Partner = Depends(get_current_partner),
                   session: AsyncSession = Depends(get_session)):
    report = await session.scalar(select(MerchantLedger).where(MerchantLedger.id == str(report_id),
        MerchantLedger.partner_id == partner.id))
    if report is None:
        raise HTTPException(404, 'Ledger not found')
    try:
        data = await asyncio.to_thread(ledger_path(report.id, get_settings()).read_bytes)
    except OSError:
        raise HTTPException(503, 'The saved PDF is unavailable. Contact support or generate a new report.') from None
    if hashlib.sha256(data).hexdigest() != report.sha256:
        raise HTTPException(503, 'The saved PDF could not be verified. Please contact support.')
    filename = f'stepsy-{report.period}-{report.starts_on}-{report.id[:8]}.pdf'
    return Response(data, media_type='application/pdf', headers={
        'Content-Disposition': f'attachment; filename="{filename}"', 'Cache-Control': 'private, no-store',
        'X-Content-Type-Options': 'nosniff'})
