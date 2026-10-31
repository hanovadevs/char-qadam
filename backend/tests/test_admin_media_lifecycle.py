"""Isolated PostgreSQL checks for store branding and non-destructive admin work."""
import io
import uuid
from urllib.parse import urlsplit

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from PIL import Image
from sqlalchemy import delete, select

from app.config import get_settings
from app.db.models import Offer, Partner, PointsLedger, Redemption, User, Voucher
from app.db.postgres import get_session_factory
from tests.test_offers import _auth, _cleanup, _email, _register, _sync_steps


def image_bytes(format='PNG'):
    data = io.BytesIO()
    image = Image.new('RGB', (1600, 900), '#0f8a78')
    exif = Image.Exif(); exif[315] = 'private-test-metadata'
    image.save(data, format=format, exif=exif)
    return data.getvalue()


@pytest_asyncio.fixture
async def store(admin_client, tmp_path, monkeypatch):
    monkeypatch.setattr(get_settings(), 'media_directory', str(tmp_path))
    response = await admin_client.post('/admin/partners', json={
        'name': 'Lifecycle cover store', 'email': f'media-{uuid.uuid4().hex}@example.com',
        'password': 'test-merchant-password', 'generate_api_key': True})
    assert response.status_code == 201, response.text
    data = response.json()
    yield data
    async with get_session_factory()() as session:
        await session.execute(delete(Offer).where(Offer.partner_id == data['id']))
        await session.execute(delete(User).where(User.partner_id == data['id']))
        await session.execute(delete(Partner).where(Partner.id == data['id']))
        await session.commit()


@pytest_asyncio.fixture
async def customer(store, client):
    email = _email()
    token = await _register(client, email)
    await _sync_steps(client, token, 1000)
    try:
        yield token
    finally:
        async with get_session_factory()() as session:
            user_id = await session.scalar(select(User.id).where(User.email == email))
            voucher_ids = select(Voucher.id).where(Voucher.user_id == user_id)
            await session.execute(delete(Redemption).where(Redemption.voucher_id.in_(voucher_ids)))
            await session.commit()
        await _cleanup(email)


async def new_offer(admin_client, store, **terms):
    response = await admin_client.post('/admin/offers', json={
        'partner_id': store['id'], 'title': 'Original reward', 'discount_type': 'PERCENT',
        'discount_value': 20, 'points_cost': 10, 'inventory': 5, **terms})
    assert response.status_code == 201, response.text
    return response.json()['id']


@pytest.mark.asyncio
@pytest.mark.parametrize('format', ['JPEG', 'PNG', 'WEBP'])
async def test_cover_upload_reaches_admin_and_catalog_and_survives_app_recreation(store, customer, admin_client, client, format):
    offer = await new_offer(admin_client, store)
    response = await admin_client.post(f"/admin/partners/{store['id']}/cover",
        files={'file': ('cover.' + format.lower(), image_bytes(format), 'image/' + format.lower())})
    assert response.status_code == 200, response.text
    url = response.json()['cover_image_url']; path = urlsplit(url).path
    image_response = await client.get(path)
    assert image_response.status_code == 200
    assert image_response.headers['content-type'] == 'image/webp'
    assert 'immutable' in image_response.headers['cache-control']
    assert image_response.headers['x-content-type-options'] == 'nosniff'
    normalized = Image.open(io.BytesIO(image_response.content))
    assert normalized.size == (1280, 720)
    assert not normalized.getexif()
    assert (await admin_client.get(f"/admin/partners/{store['id']}")).json()['cover_image_url'] == url
    rows = (await admin_client.get('/admin/partners')).json()
    assert next(row for row in rows if row['id'] == store['id'])['cover_image_url'] == url
    catalog = (await client.get('/offers', headers=_auth(customer))).json()
    assert next(row for row in catalog if row['id'] == offer)['partner_cover_image_url'] == url
    from app.main import create_app
    async with AsyncClient(transport=ASGITransport(app=create_app()), base_url='http://test') as restarted:
        assert (await restarted.get(path)).content == image_response.content


@pytest.mark.asyncio
async def test_cover_replacement_is_versioned_and_removal_does_not_break_cached_assets(store, admin_client, client):
    async def upload():
        response = await admin_client.post(f"/admin/partners/{store['id']}/cover",
            files={'file': ('cover.png', image_bytes(), 'image/png')})
        assert response.status_code == 200
        return response.json()['cover_image_url']
    first, second = await upload(), await upload()
    assert first != second
    assert (await client.get(urlsplit(first).path)).status_code == 200
    assert (await admin_client.delete(f"/admin/partners/{store['id']}/cover")).json()['cover_image_url'] is None
    assert (await admin_client.get(f"/admin/partners/{store['id']}")).json()['cover_image_url'] is None
    assert (await client.get(urlsplit(second).path)).status_code == 200


@pytest.mark.asyncio
@pytest.mark.parametrize('kind, expected', [('svg', 422), ('corrupt', 422), ('oversized', 413), ('gif', 415)])
async def test_bad_cover_never_changes_store_or_creates_asset(store, admin_client, tmp_path, kind, expected):
    body = {'svg': b'<svg onload="alert(1)"></svg>', 'corrupt': b'not an image',
        'oversized': b'x' * (4 * 1024 * 1024 + 1), 'gif': image_bytes('GIF')}[kind]
    response = await admin_client.post(f"/admin/partners/{store['id']}/cover", files={'file': ('cover.png', body, 'image/png')})
    assert response.status_code == expected, response.text
    assert (await admin_client.get(f"/admin/partners/{store['id']}")).json()['cover_image_url'] is None
    assert list(tmp_path.rglob('*.webp')) == []


@pytest.mark.asyncio
async def test_cover_is_admin_only_and_paths_cannot_reveal_private_files(store, customer, client, tmp_path):
    response = await client.post(f"/admin/partners/{store['id']}/cover", headers=_auth(customer),
        files={'file': ('cover.png', image_bytes(), 'image/png')})
    assert response.status_code == 403
    assert list(tmp_path.rglob('*.webp')) == []
    for path in ['/media/store-covers/.env', '/media/store-covers/..%2f.env', '/media/store-covers/not-a-uuid.webp']:
        assert (await client.get(path)).status_code == 404


@pytest.mark.asyncio
async def test_unknown_store_upload_cleans_uncommitted_asset(store, admin_client, tmp_path):
    response = await admin_client.post(f'/admin/partners/{uuid.uuid4()}/cover',
        files={'file': ('cover.png', image_bytes(), 'image/png')})
    assert response.status_code == 404
    assert list(tmp_path.rglob('*.webp')) == []


@pytest.mark.asyncio
async def test_archive_hides_new_claims_but_existing_voucher_still_redeems(store, customer, admin_client, client):
    offer = await new_offer(admin_client, store)
    other_offer = await new_offer(admin_client, store, points_cost=0)
    purchase = await client.post(f'/offers/{offer}/redeem', headers=_auth(customer))
    assert purchase.status_code == 201
    assert (await admin_client.post(f"/admin/partners/{store['id']}/archive")).status_code == 200
    catalog = (await client.get('/offers', headers=_auth(customer))).json()
    assert offer not in [item['id'] for item in catalog]
    assert (await client.post(f'/offers/{other_offer}/redeem', headers=_auth(customer))).status_code == 409
    assert (await admin_client.delete(f"/admin/partners/{store['id']}")).status_code == 409
    assert (await admin_client.post(f'/admin/offers/{offer}/archive')).status_code == 200
    assert (await admin_client.delete(f'/admin/offers/{offer}')).status_code == 409
    headers = {'X-Partner-Key': store['raw_api_key'], 'Authorization': ''}
    validation = await client.post('/partner/v1/vouchers/validate', headers=headers, json={'token': purchase.json()['short_code']})
    assert validation.status_code == 200, validation.text
    used = await client.post('/partner/v1/vouchers/redeem', headers=headers, json={'nonce': validation.json()['nonce']})
    assert used.status_code == 200, used.text
    assert (await client.get('/vouchers?status=redeemed', headers=_auth(customer))).json()[0]['id'] == purchase.json()['voucher_id']


@pytest.mark.asyncio
async def test_unused_archived_records_can_be_deleted_and_restored_without_changing_prior_status(store, admin_client):
    offer = await new_offer(admin_client, store, status='INACTIVE')
    assert (await admin_client.delete(f'/admin/offers/{offer}')).status_code == 409
    assert (await admin_client.post(f'/admin/offers/{offer}/archive')).status_code == 200
    assert (await admin_client.post(f'/admin/offers/{offer}/restore')).status_code == 200
    row = next(row for row in (await admin_client.get('/admin/offers')).json() if row['id'] == offer)
    assert row['archived_at'] is None and row['status'] == 'INACTIVE' and row['can_delete']
    await admin_client.post(f'/admin/offers/{offer}/archive')
    assert (await admin_client.delete(f'/admin/offers/{offer}')).status_code == 200
    assert (await admin_client.delete(f"/admin/partners/{store['id']}")).status_code == 409
    await admin_client.post(f"/admin/partners/{store['id']}/archive")
    assert (await admin_client.delete(f"/admin/partners/{store['id']}")).status_code == 200


@pytest.mark.asyncio
async def test_claimed_deal_benefits_are_immutable_but_copy_stock_and_future_points_price_can_change(store, customer, admin_client, client):
    offer = await new_offer(admin_client, store, min_basket=100)
    assert (await client.post(f'/offers/{offer}/redeem', headers=_auth(customer))).status_code == 201
    for terms in [{'discount_type': 'FIXED'}, {'discount_value': 30}, {'min_basket': None}, {'min_basket': 150}]:
        response = await admin_client.patch(f'/admin/offers/{offer}', json=terms)
        assert response.status_code == 409, response.text
    updated = await admin_client.patch(f'/admin/offers/{offer}', json={'title': 'Typo fixed', 'inventory': 8, 'points_cost': 12})
    assert updated.status_code == 200
    row = next(row for row in (await admin_client.get('/admin/offers')).json() if row['id'] == offer)
    assert row['has_history'] and not row['can_delete']
    assert row['discount_value'] == 20 and row['min_basket'] == 100 and row['inventory'] == 8


@pytest.mark.asyncio
async def test_admin_deactivation_preserves_history_and_revokes_old_tokens_permanently(store, customer, admin_client, client):
    from app.services.security import decode_access_claims
    user_id = decode_access_claims(customer)['sub']
    assert (await admin_client.delete(f'/admin/users/{user_id}')).status_code == 409
    assert (await admin_client.patch(f'/admin/users/{user_id}/status', json={'status': 'DELETED'})).status_code == 200
    assert (await admin_client.delete(f'/admin/users/{user_id}')).status_code == 409
    assert (await client.get('/auth/me', headers=_auth(customer))).status_code == 401
    assert (await admin_client.patch(f'/admin/users/{user_id}/status', json={'status': 'ACTIVE'})).status_code == 200
    assert (await client.get('/auth/me', headers=_auth(customer))).status_code == 401
    row = next(row for row in (await admin_client.get('/admin/users')).json() if row['id'] == user_id)
    assert row['points_balance'] == 10 and row['total_steps'] == 1000 and not row['can_delete']


@pytest.mark.asyncio
async def test_vouchers_cannot_be_deleted_or_manually_marked_used_then_reactivated(store, customer, admin_client, client):
    offer = await new_offer(admin_client, store)
    purchase = await client.post(f'/offers/{offer}/redeem', headers=_auth(customer))
    voucher_id = purchase.json()['voucher_id']
    assert (await admin_client.delete(f'/admin/vouchers/{voucher_id}')).status_code == 409
    assert (await admin_client.patch(f'/admin/vouchers/{voucher_id}', json={'status': 'REDEEMED'})).status_code == 409
    assert (await admin_client.patch(f'/admin/vouchers/{voucher_id}', json={'status': 'CANCELLED'})).status_code == 200
    assert (await admin_client.patch(f'/admin/vouchers/{voucher_id}', json={'status': 'ISSUED'})).status_code == 409
    wallet = await client.get('/vouchers?status=cancelled', headers=_auth(customer))
    assert wallet.status_code == 200 and wallet.json()[0]['id'] == voucher_id
    assert (await client.get('/points/balance', headers=_auth(customer))).json()['balance'] == 0
    async with get_session_factory()() as session:
        assert await session.get(Voucher, voucher_id) is not None


@pytest.mark.asyncio
async def test_cover_pixel_limit_and_storage_failure_leave_database_unchanged(store, admin_client, monkeypatch, tmp_path):
    from app.services import store_cover
    monkeypatch.setattr(store_cover, 'MAX_COVER_PIXELS', 1000)
    upload = lambda: admin_client.post(f"/admin/partners/{store['id']}/cover",
        files={'file': ('cover.png', image_bytes(), 'image/png')})
    assert (await upload()).status_code == 422
    monkeypatch.setattr(store_cover, 'MAX_COVER_PIXELS', 25_000_000)
    blocked = tmp_path / 'not-a-directory'; blocked.write_text('fixture')
    monkeypatch.setattr(get_settings(), 'media_directory', str(blocked))
    assert (await upload()).status_code == 503
    assert (await admin_client.get(f"/admin/partners/{store['id']}")).json()['cover_image_url'] is None


@pytest.mark.asyncio
async def test_unused_account_must_be_deactivated_before_permanent_deletion(store, admin_client, client):
    from app.services.security import decode_access_claims
    email = _email()
    try:
        token = await _register(client, email)
        user_id = decode_access_claims(token)['sub']
        assert (await admin_client.delete(f'/admin/users/{user_id}')).status_code == 409
        assert (await admin_client.patch(f'/admin/users/{user_id}/status', json={'status': 'DELETED'})).status_code == 200
        assert (await admin_client.delete(f'/admin/users/{user_id}')).status_code == 200
        assert (await client.get('/auth/me', headers=_auth(token))).status_code == 401
    finally:
        await _cleanup(email)


@pytest.mark.asyncio
@pytest.mark.parametrize('retained_history', ['ledger', 'receipt'])
async def test_removed_voucher_does_not_make_purchased_deal_or_store_deletable(store, customer, admin_client, client, retained_history):
    offer = await new_offer(admin_client, store)
    result = await client.post(f'/offers/{offer}/redeem', headers={**_auth(customer), 'Idempotency-Key': str(uuid.uuid4())})
    assert result.status_code == 201
    async with get_session_factory()() as session:
        await session.execute(delete(Voucher).where(Voucher.id == result.json()['voucher_id']))
        if retained_history == 'receipt':
            await session.execute(delete(PointsLedger).where(PointsLedger.ref_id == offer))
        else:
            from app.db.models import RedemptionRequest
            await session.execute(delete(RedemptionRequest).where(RedemptionRequest.offer_id == offer))
        await session.commit()
    await admin_client.post(f'/admin/offers/{offer}/archive')
    await admin_client.post(f"/admin/partners/{store['id']}/archive")
    assert (await admin_client.delete(f'/admin/offers/{offer}')).status_code == 409
    assert (await admin_client.delete(f"/admin/partners/{store['id']}")).status_code == 409
