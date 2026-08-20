"""Full End-to-End Integration Test for Qadam MVP (Phase M4).

Executes the complete user & merchant lifecycle in a single deterministic sequence:
1.  Register a new user account (POST /auth/register)
2.  Ingest daily steps (POST /activity/sync) -> 15,000 steps = 150 points earned
3.  Check points balance & ledger (GET /points/balance & GET /points/history)
4.  Browse active rewards catalog (GET /offers)
5.  Redeem an offer (POST /offers/{id}/redeem) -> points deducted, voucher & token issued
6.  Verify voucher in wallet (GET /vouchers?status=active)
7.  Partner POS validates voucher token (POST /partner/v1/vouchers/validate) -> receives HMAC nonce
8.  Partner POS redeems voucher (POST /partner/v1/vouchers/redeem) -> status updated to REDEEMED
9.  Verify voucher status in wallet (GET /vouchers?status=redeemed)
10. Attempt double redemption -> rejected with 409 Conflict
11. Update profile (PATCH /users/me)
12. Soft-delete user account (DELETE /users/me) -> JWT revoked
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone

import pytest
from httpx import AsyncClient
from sqlalchemy import delete, select

from app.db.models import (
    ActivityDaily,
    Offer,
    OfferStatus,
    Partner,
    PartnerStatus,
    PointsLedger,
    Redemption,
    User,
    Voucher,
)
from app.db.postgres import get_session_factory
from app.services.partner_auth import hash_api_key


@pytest.mark.asyncio
async def test_full_e2e_lifecycle(client: AsyncClient) -> None:
    factory = get_session_factory()
    email = f"e2e_{uuid.uuid4().hex[:8]}@example.com"
    password = "E2EPassword123!"
    raw_partner_key = f"e2e-key-{uuid.uuid4().hex}"
    
    partner_id = str(uuid.uuid4())
    offer_id = str(uuid.uuid4())

    # --- SETUP: Seed a partner and active offer ---
    async with factory() as session:
        partner = Partner(
            id=partner_id,
            name="E2E Test Brand",
            api_key_hash=hash_api_key(raw_partner_key),
            status=PartnerStatus.ACTIVE,
        )
        session.add(partner)

        offer = Offer(
            id=offer_id,
            partner_id=partner_id,
            title="E2E $10 Voucher",
            description="Special E2E offer",
            discount_type="FIXED",
            discount_value=10.00,
            points_cost=100,
            inventory=10,
            status=OfferStatus.ACTIVE,
            starts_at=datetime.now(timezone.utc),
        )
        session.add(offer)
        await session.commit()

    try:
        # --- STEP 1: Register User ---
        reg_resp = await client.post(
            "/auth/register",
            json={"email": email, "password": password, "country": "PK", "timezone": "Asia/Karachi"},
        )
        assert reg_resp.status_code == 201, reg_resp.text
        user_token = reg_resp.json()["access_token"]
        user_headers = {"Authorization": f"Bearer {user_token}"}
        partner_headers = {"X-Partner-Key": raw_partner_key}

        # --- STEP 2: Sync Steps (15,000 steps -> 150 points) ---
        today_str = datetime.now(timezone.utc).date().isoformat()
        sync_resp = await client.post(
            "/activity/sync",
            json={
                "local_date": today_str,
                "eligible_steps": 15000,
                "source": "health",
                "sync_key": str(uuid.uuid4()),
            },
            headers=user_headers,
        )
        assert sync_resp.status_code == 200, sync_resp.text
        sync_data = sync_resp.json()
        assert sync_data["eligible_steps"] == 15000
        assert sync_data["points_awarded"] == 150
        assert sync_data["balance"] == 150

        # --- STEP 3: Verify Points Balance & History ---
        bal_resp = await client.get("/points/balance", headers=user_headers)
        assert bal_resp.status_code == 200
        assert bal_resp.json()["balance"] == 150
        assert bal_resp.json()["total_earned"] == 150

        hist_resp = await client.get("/points/history", headers=user_headers)
        assert hist_resp.status_code == 200
        assert hist_resp.json()["total"] == 1
        assert hist_resp.json()["entries"][0]["reason"] == "STEP_EARN"

        # --- STEP 4: Browse Offers Catalog ---
        catalog_resp = await client.get("/offers", headers=user_headers)
        assert catalog_resp.status_code == 200
        offer_ids = [o["id"] for o in catalog_resp.json()]
        assert offer_id in offer_ids

        # --- STEP 5: Redeem Offer (Cost: 100 points) ---
        redeem_resp = await client.post(f"/offers/{offer_id}/redeem", headers=user_headers)
        assert redeem_resp.status_code == 201, redeem_resp.text
        redeem_data = redeem_resp.json()
        voucher_id = redeem_data["voucher_id"]
        short_code = redeem_data["short_code"]
        raw_qr_token = redeem_data["token"]
        assert redeem_data["points_spent"] == 100
        assert redeem_data["balance"] == 50  # 150 - 100

        # --- STEP 6: Check Active Voucher in Wallet ---
        wallet_resp = await client.get("/vouchers?status=active", headers=user_headers)
        assert wallet_resp.status_code == 200
        active_vouchers = wallet_resp.json()
        assert any(v["id"] == voucher_id for v in active_vouchers)

        # --- STEP 7: Partner POS Validates Voucher QR Token ---
        val_resp = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": raw_qr_token},
            headers=partner_headers,
        )
        assert val_resp.status_code == 200, val_resp.text
        val_data = val_resp.json()
        assert val_data["voucher_id"] == voucher_id
        assert val_data["short_code"] == short_code
        nonce = val_data["nonce"]

        # --- STEP 8: Partner POS Redeems Voucher ---
        partner_redeem_resp = await client.post(
            "/partner/v1/vouchers/redeem",
            json={"nonce": nonce, "store_id": "store-e2e-01", "order_reference": "ORDER-999"},
            headers=partner_headers,
        )
        assert partner_redeem_resp.status_code == 200, partner_redeem_resp.text
        assert partner_redeem_resp.json()["voucher_id"] == voucher_id

        # --- STEP 9: Verify Voucher is now in Redeemed Wallet ---
        redeemed_wallet = await client.get("/vouchers?status=redeemed", headers=user_headers)
        assert redeemed_wallet.status_code == 200
        assert any(v["id"] == voucher_id for v in redeemed_wallet.json())

        active_wallet = await client.get("/vouchers?status=active", headers=user_headers)
        assert not any(v["id"] == voucher_id for v in active_wallet.json())

        # --- STEP 10: Verify Double Redemption Rejection (409) ---
        double_val = await client.post(
            "/partner/v1/vouchers/validate",
            json={"token": raw_qr_token},
            headers=partner_headers,
        )
        assert double_val.status_code == 409

        # --- STEP 11: Update User Profile ---
        patch_resp = await client.patch(
            "/users/me",
            json={"timezone": "UTC"},
            headers=user_headers,
        )
        assert patch_resp.status_code == 200
        assert patch_resp.json()["timezone"] == "UTC"

        # --- STEP 12: Soft-Delete Account ---
        del_resp = await client.delete("/users/me", headers=user_headers)
        assert del_resp.status_code == 204

        # Verify token is immediately revoked
        revoked_me = await client.get("/auth/me", headers=user_headers)
        assert revoked_me.status_code == 403

    finally:
        # --- CLEANUP ---
        async with factory() as session:
            res = await session.execute(select(User).where(User.email == email))
            user = res.scalar_one_or_none()
            if user:
                await session.execute(delete(Redemption).where(Redemption.partner_id == partner_id))
                await session.execute(delete(Voucher).where(Voucher.user_id == user.id))
                await session.execute(delete(PointsLedger).where(PointsLedger.user_id == user.id))
                await session.execute(delete(ActivityDaily).where(ActivityDaily.user_id == user.id))
                await session.execute(delete(User).where(User.id == user.id))
            await session.execute(delete(Offer).where(Offer.id == offer_id))
            await session.execute(delete(Partner).where(Partner.id == partner_id))
            await session.commit()
