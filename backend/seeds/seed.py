"""Seed script — inserts a demo partner (with API key) and 3 offers for local dev.

Run from the backend/ directory:
    python -m seeds.seed

Requires DATABASE_URL to be set (reads from .env via app.config).

On first run the demo partner's raw API key is printed once — save it.
Subsequent runs are idempotent (key is NOT re-generated if one exists).
"""
from __future__ import annotations

import asyncio
import secrets
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import get_settings
from app.db.models import DiscountType, Offer, OfferStatus, Partner, PartnerStatus
from app.services.partner_auth import hash_api_key


DEMO_PARTNER_ID = "00000000-0000-0000-0000-000000000001"

DEMO_OFFERS = [
    {
        "title": "10% Off Your Next Purchase",
        "description": "Enjoy 10% off any order over $20 at QadamShop.",
        "discount_type": DiscountType.PERCENT,
        "discount_value": 10.00,
        "points_cost": 500,
        "min_basket": 20.00,
        "inventory": None,   # unlimited
    },
    {
        "title": "$5 Flat Discount",
        "description": "Get $5 off any purchase, no minimum spend.",
        "discount_type": DiscountType.FIXED,
        "discount_value": 5.00,
        "points_cost": 250,
        "min_basket": None,
        "inventory": 100,
    },
    {
        "title": "Free Energy Bar",
        "description": "Claim a complimentary energy bar with any order.",
        "discount_type": DiscountType.FREE_ITEM,
        "discount_value": 0.00,
        "points_cost": 150,
        "min_basket": None,
        "inventory": 50,
    },
]


async def seed() -> None:
    settings = get_settings()
    engine = create_async_engine(settings.database_url, echo=False)
    factory = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)

    async with factory() as session:
        # ---------------------------------------------------------------- partner
        existing_partner: Partner | None = await session.get(Partner, DEMO_PARTNER_ID)

        if existing_partner is None:
            # First run — generate a fresh API key
            raw_key = secrets.token_urlsafe(32)
            partner = Partner(
                id=DEMO_PARTNER_ID,
                name="QadamShop (Demo)",
                status=PartnerStatus.ACTIVE,
                api_key_hash=hash_api_key(raw_key),
            )
            session.add(partner)
            print(f"[seed] Created partner: {partner.name}")
            print()
            print("  ┌─────────────────────────────────────────────────────┐")
            print(f"  │  DEMO PARTNER API KEY (shown once — save it now!)  │")
            print(f"  │  {raw_key:<51}│")
            print("  │  Header: X-Partner-Key: <key above>                │")
            print("  └─────────────────────────────────────────────────────┘")
            print()
        elif existing_partner.api_key_hash is None:
            # Existing partner without a key — add one
            raw_key = secrets.token_urlsafe(32)
            existing_partner.api_key_hash = hash_api_key(raw_key)
            print(f"[seed] Added API key to existing partner: {existing_partner.name}")
            print()
            print("  ┌─────────────────────────────────────────────────────┐")
            print(f"  │  DEMO PARTNER API KEY (shown once — save it now!)  │")
            print(f"  │  {raw_key:<51}│")
            print("  │  Header: X-Partner-Key: <key above>                │")
            print("  └─────────────────────────────────────────────────────┘")
            print()
        else:
            print(f"[seed] Partner already exists with API key: {existing_partner.name}")

        # ----------------------------------------------------------------- offers
        now = datetime.now(timezone.utc)
        ends_at = now + timedelta(days=90)

        for offer_data in DEMO_OFFERS:
            result = await session.execute(
                text("SELECT id FROM offers WHERE partner_id = :pid AND title = :title LIMIT 1"),
                {"pid": DEMO_PARTNER_ID, "title": offer_data["title"]},
            )
            row = result.fetchone()
            if row is None:
                offer = Offer(
                    id=str(uuid.uuid4()),
                    partner_id=DEMO_PARTNER_ID,
                    starts_at=now,
                    ends_at=ends_at,
                    status=OfferStatus.ACTIVE,
                    **offer_data,
                )
                session.add(offer)
                print(f"[seed] Created offer: {offer_data['title']}")
            else:
                print(f"[seed] Offer already exists: {offer_data['title']}")

        await session.commit()

    await engine.dispose()
    print("[seed] Done.")


if __name__ == "__main__":
    asyncio.run(seed())
