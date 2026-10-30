import io
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal

import pytest
from pypdf import PdfReader
from sqlalchemy import select

from app.config import get_settings
from app.db.models import Partner, Offer, Voucher, Redemption, DiscountType, MerchantLedger, User
from app.db.postgres import get_session_factory
from app.services.merchant_ledger import PAKISTAN, period_bounds, utc_boundaries, ledger_path
from tests.auth_helpers import auth_headers, register_verified


@pytest.fixture
def private_media(monkeypatch, tmp_path):
    monkeypatch.setattr(get_settings(), 'media_directory', str(tmp_path))
    return tmp_path


async def store(client):
    email = f'ledger-{uuid.uuid4().hex}@stepsyapp.com'
    created = await client.post('/admin/partners', json={'name': 'Ledger test & Store', 'email': email, 'password': 'ledger-password-123'})
    assert created.status_code == 201, created.text
    client.headers['X-Device-ID'] = uuid.uuid4().hex * 2
    login = await client.post('/auth/login', json={'email': email, 'password': 'ledger-password-123'})
    assert login.status_code == 200
    return created.json()['id'], auth_headers(login.json()['access_token']), login.json()['user']['id']


async def redemption(partner_id, user_id, when, kind=DiscountType.PERCENT, value=20):
    async with get_session_factory()() as s:
        offer = Offer(id=str(uuid.uuid4()), partner_id=partner_id, title='Reward <special> & terms',
            points_cost=10, discount_type=kind, discount_value=value)
        s.add(offer)
        await s.flush()
        voucher = Voucher(id=str(uuid.uuid4()), user_id=user_id, offer_id=offer.id,
            short_code='SR-' + uuid.uuid4().hex[:4].upper() + '-' + uuid.uuid4().hex[:4].upper(),
            token_hash=uuid.uuid4().hex * 2, expires_at=when + timedelta(days=30))
        s.add(voucher)
        await s.flush()
        s.add(Redemption(id=str(uuid.uuid4()), partner_id=partner_id, voucher_id=voucher.id,
            discount_value=value, redeemed_at=when, order_reference='Order <&> receipt', store_id='BRANCH-01'))
        await s.commit()


def test_calendar_period_boundaries_include_leap_month_and_monday_week():
    assert period_bounds('month', date(2024, 2, 20)) == (date(2024, 2, 1), date(2024, 2, 29))
    assert period_bounds('week', date(2026, 1, 1)) == (date(2025, 12, 29), date(2026, 1, 4))
    first, end = utc_boundaries(date(2026, 1, 1), date(2026, 1, 31))
    assert first.astimezone(timezone.utc).isoformat() == '2025-12-31T19:00:00+00:00'
    assert end.astimezone(timezone.utc).isoformat() == '2026-01-31T19:00:00+00:00'


@pytest.mark.asyncio
async def test_private_ledger_snapshot_history_period_filter_units_and_idempotency(admin_client, private_media):
    partner, headers, user = await store(admin_client)
    await redemption(partner, user, datetime(2026, 1, 1, 0, 0, tzinfo=PAKISTAN))
    await redemption(partner, user, datetime(2026, 1, 15, 13, 0, tzinfo=PAKISTAN), DiscountType.FIXED, 250)
    await redemption(partner, user, datetime(2026, 1, 31, 23, 59, tzinfo=PAKISTAN), DiscountType.FREE_ITEM, 0)
    await redemption(partner, user, datetime(2026, 2, 1, 0, 0, tzinfo=PAKISTAN), DiscountType.FIXED, 999)
    body = {'period': 'month', 'anchor_date': '2026-01-15', 'request_id': str(uuid.uuid4())}
    response = await admin_client.post('/partner/v1/ledgers', headers=headers, json=body)
    assert response.status_code == 201, response.text
    report = response.json()
    assert report['row_count'] == 3 and Decimal(report['fixed_discount_total']) == 250
    assert report['timezone'] == 'Asia/Karachi'
    pdf = await admin_client.get(f"/partner/v1/ledgers/{report['id']}/pdf", headers=headers)
    assert pdf.status_code == 200 and pdf.headers['content-type'] == 'application/pdf'
    assert pdf.headers['cache-control'] == 'private, no-store'
    reader = PdfReader(io.BytesIO(pdf.content))
    text = '\n'.join(page.extract_text() for page in reader.pages)
    assert '20%' in text and 'PKR 250.00' in text and 'Free item' in text
    assert '999' not in text and 'Reward <special> & terms' in text
    assert 'Order <&> receipt' in text
    assert reader.metadata.author == 'Stepsy'
    original = pdf.content
    replay = await admin_client.post('/partner/v1/ledgers', headers=headers, json=body)
    assert replay.json()['id'] == report['id']
    assert (await admin_client.post('/partner/v1/ledgers', headers=headers, json={**body, 'period': 'week'})).status_code == 409
    history = await admin_client.get('/partner/v1/ledgers', headers=headers)
    assert [row['id'] for row in history.json()] == [report['id']]
    # Re-downloading never silently regenerates an older report with newer data.
    await redemption(partner, user, datetime(2026, 1, 10, tzinfo=PAKISTAN), DiscountType.FIXED, 400)
    assert (await admin_client.get(f"/partner/v1/ledgers/{report['id']}/pdf", headers=headers)).content == original
    other, other_headers, _ = await store(admin_client)
    assert (await admin_client.get(f"/partner/v1/ledgers/{report['id']}/pdf", headers=other_headers)).status_code == 404
    assert (await admin_client.get('/partner/v1/ledgers', headers=other_headers)).json() == []
    assert (await admin_client.get(f"/media/merchant-ledgers/{report['id']}.pdf")).status_code == 404
    # No token can turn a private report path into an arbitrary file download.
    assert (await admin_client.get('/partner/v1/ledgers/not-a-uuid/pdf', headers=headers)).status_code == 422


@pytest.mark.asyncio
async def test_empty_ledger_is_real_pdf_and_customers_cannot_access_ledgers(admin_client, private_media):
    _, headers, _ = await store(admin_client)
    report = await admin_client.post('/partner/v1/ledgers', headers=headers, json={'period': 'week', 'anchor_date': '2026-01-01', 'request_id': str(uuid.uuid4())})
    assert report.status_code == 201 and report.json()['row_count'] == 0
    pdf = await admin_client.get(f"/partner/v1/ledgers/{report.json()['id']}/pdf", headers=headers)
    assert 'No vouchers were redeemed' in PdfReader(io.BytesIO(pdf.content)).pages[0].extract_text()
    customer = await register_verified(admin_client, json={'email': f'pdf-customer-{uuid.uuid4().hex}@example.com', 'password': 'personal-password'})
    assert (await admin_client.get('/partner/v1/ledgers', headers=auth_headers(customer.json()['access_token']))).status_code == 403
    assert (await admin_client.post('/partner/v1/ledgers', headers=headers, json={'period': 'month', 'anchor_date': '2099-01-01', 'request_id': str(uuid.uuid4())})).status_code == 422
    # Detect damaged storage rather than presenting altered content as the saved ledger.
    ledger_path(report.json()['id'], get_settings()).write_bytes(b'corrupted')
    assert (await admin_client.get(f"/partner/v1/ledgers/{report.json()['id']}/pdf", headers=headers)).status_code == 503
