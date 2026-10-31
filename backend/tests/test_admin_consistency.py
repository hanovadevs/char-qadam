"""Shared admin/customer/merchant records stay consistent after optimized reads."""
import uuid
import pytest
from sqlalchemy import delete, event, select

from app.db.models import (ActivityDaily, DeviceActivityDaily, DeviceBinding, Offer,
    Partner, PointsLedger, Redemption, RedemptionRequest, User, Voucher)
from app.db.postgres import get_read_engine, get_session_factory
from app.services.local_date import local_today
from tests.auth_helpers import auth_headers, register_verified


@pytest.mark.asyncio
async def test_admin_customer_and_merchant_share_one_reward_lifecycle(client, admin_client):
    suffix = uuid.uuid4().hex
    customer_email = f'consistency-{suffix}@example.com'
    merchant_email = f'store-{suffix}@example.com'
    customer_id = partner_id = device = None
    baseline = (await admin_client.get('/admin/analytics/overview')).json()
    try:
        registered = await register_verified(client, json={'email': customer_email, 'password': 'test-password-123'})
        customer_id = registered.json()['user']['id']
        headers = auth_headers(registered.json()['access_token'])
        device = headers['X-Device-ID']
        created = await admin_client.post('/admin/partners', json={
            'name': f'Consistency store {suffix}', 'email': merchant_email,
            'password': 'test-merchant-123', 'generate_api_key': True,
            'location': 'Lahore', 'google_maps_url': 'https://maps.app.goo.gl/OriginalBranch'})
        assert created.status_code == 201, created.text
        partner_id = created.json()['id']
        merchant_headers = {'X-Partner-Key': created.json()['raw_api_key']}
        created_offer = await admin_client.post('/admin/offers', json={
            'partner_id': partner_id, 'title': f'Consistency offer {suffix}',
            'discount_type': 'PERCENT', 'discount_value': 20, 'points_cost': 5,
            'inventory': 3, 'status': 'ACTIVE'})
        assert created_offer.status_code == 201, created_offer.text
        offer_id = created_offer.json()['id']

        synced = await client.post('/activity/sync', headers=headers, json={
            'local_date': local_today().isoformat(), 'eligible_steps': 1000,
            'source': 'health', 'sync_key': str(uuid.uuid4())})
        assert synced.status_code == 200
        assert synced.json()['balance'] == 10

        async def directory_row():
            rows = (await admin_client.get('/admin/users', params={'search': customer_email})).json()
            assert len(rows) == 1
            return rows[0]
        row = await directory_row()
        assert row['total_steps'] == 1000 and row['points_balance'] == 10

        changed = await admin_client.patch(f'/admin/partners/{partner_id}', json={
            'location': 'Karachi', 'google_maps_url': 'https://maps.app.goo.gl/UpdatedBranch'})
        assert changed.status_code == 200
        assert (await admin_client.patch(f'/admin/offers/{offer_id}', json={'points_cost': 6})).status_code == 200
        catalog = (await client.get('/offers', headers=headers)).json()
        offer = next(item for item in catalog if item['id'] == offer_id)
        assert offer['partner_location'] == 'Karachi'
        assert offer['partner_google_maps_url'] == 'https://maps.app.goo.gl/UpdatedBranch'
        assert offer['points_cost'] == 6

        purchase_headers = {**headers, 'Idempotency-Key': str(uuid.uuid4())}
        purchased = await client.post(f'/offers/{offer_id}/redeem', headers=purchase_headers,
                                      json={'expected_points_cost': 6})
        assert purchased.status_code in (200, 201), purchased.text
        voucher_id, code = purchased.json()['voucher_id'], purchased.json()['short_code']
        assert purchased.json()['balance'] == 4
        replay = await client.post(f'/offers/{offer_id}/redeem', headers=purchase_headers,
                                  json={'expected_points_cost': 6})
        assert replay.json()['voucher_id'] == voucher_id
        assert replay.json()['balance'] == 4
        assert (await directory_row())['points_balance'] == 4

        # Search by email and filters are the same ones sent by the admin UI.
        admin_vouchers = (await admin_client.get('/admin/vouchers', params={'search': customer_email})).json()
        assert len(admin_vouchers) == 1
        assert admin_vouchers[0]['short_code'] == code
        assert (await admin_client.get('/admin/vouchers', params={'offer_id': str(uuid.uuid4())})).json() == []
        assert (await admin_client.get('/admin/vouchers', params={'partner_id': str(uuid.uuid4())})).json() == []
        wallet = (await client.get('/vouchers?status=active', headers=headers)).json()
        assert any(v['id'] == voucher_id and v['short_code'] == code for v in wallet)

        validation = await client.post('/partner/v1/vouchers/validate', headers=merchant_headers, json={'token': code})
        assert validation.status_code == 200, validation.text
        redeemed = await client.post('/partner/v1/vouchers/redeem', headers=merchant_headers,
                                    json={'nonce': validation.json()['nonce'], 'store_id': partner_id,
                                          'order_reference': f'consistency-{suffix}'})
        assert redeemed.status_code == 200, redeemed.text
        rejected = await client.post('/partner/v1/vouchers/redeem', headers=merchant_headers,
                                     json={'nonce': validation.json()['nonce']})
        assert rejected.status_code == 409
        admin_vouchers = (await admin_client.get('/admin/vouchers', params={'search': code})).json()
        assert len(admin_vouchers) == 1 and admin_vouchers[0]['status'] == 'REDEEMED'
        wallet = (await client.get('/vouchers?status=redeemed', headers=headers)).json()
        assert any(v['id'] == voucher_id for v in wallet)

        adjusted = await admin_client.post(f'/admin/users/{customer_id}/adjust-points',
                                          json={'delta': 2, 'reason_note': 'Consistency test adjustment'})
        assert adjusted.status_code == 200
        assert (await client.get('/points/balance', headers=headers)).json()['balance'] == 6
        assert (await client.get('/activity/today', headers=headers)).json()['balance'] == 6
        assert (await directory_row())['points_balance'] == 6
        updated_offer = next(o for o in (await admin_client.get('/admin/offers')).json() if o['id'] == offer_id)
        assert updated_offer['inventory'] == 2

        # Query counts must remain constant as the user directory grows.
        for path in ['/admin/users', '/admin/partners', '/admin/offers', '/admin/vouchers',
                     '/admin/redemptions?limit=8', '/admin/ledger', '/admin/analytics/overview']:
            statements = []
            def capture(_conn, _cursor, statement, _params, _context, _many):
                if statement.lstrip().upper().startswith(('SELECT', 'WITH')): statements.append(statement)
            engine = get_read_engine().sync_engine
            event.listen(engine, 'before_cursor_execute', capture)
            try:
                response = await admin_client.get(path)
                assert response.status_code == 200, response.text
            finally:
                event.remove(engine, 'before_cursor_execute', capture)
            assert len(statements) == 1, (path, len(statements))
        overview = (await admin_client.get('/admin/analytics/overview')).json()
        assert overview['total_steps'] == baseline['total_steps'] + 1000
        assert overview['vouchers_redeemed'] == baseline['vouchers_redeemed'] + 1
    finally:
        async with get_session_factory()() as session:
            if partner_id:
                await session.execute(delete(Redemption).where(Redemption.partner_id == partner_id))
                offers = select(Offer.id).where(Offer.partner_id == partner_id)
                await session.execute(delete(RedemptionRequest).where(RedemptionRequest.offer_id.in_(offers)))
                await session.execute(delete(Voucher).where(Voucher.offer_id.in_(offers)))
                await session.execute(delete(Offer).where(Offer.partner_id == partner_id))
                await session.execute(delete(User).where(User.partner_id == partner_id))
                await session.execute(delete(Partner).where(Partner.id == partner_id))
            if customer_id:
                await session.execute(delete(PointsLedger).where(PointsLedger.user_id == customer_id))
                await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == customer_id))
                await session.execute(delete(User).where(User.id == customer_id))
            if device:
                await session.execute(delete(DeviceActivityDaily).where(DeviceActivityDaily.device_id == device))
                await session.execute(delete(DeviceBinding).where(DeviceBinding.id == device))
            await session.commit()
