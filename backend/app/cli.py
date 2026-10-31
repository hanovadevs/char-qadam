"""Administrative CLI for operations and merchant provisioning."""
import argparse
import asyncio
import secrets
import uuid

from sqlalchemy import select

from app.db.models import Partner, PartnerStatus
from app.db.postgres import get_session_factory
from app.services.partner_auth import hash_api_key


async def create_partner_cli(name: str) -> None:
    factory = get_session_factory()
    async with factory() as session:
        existing = await session.execute(
            select(Partner).where(Partner.name == name.strip())
        )
        if existing.scalar_one_or_none() is not None:
            print(f"[ERROR] Partner '{name}' already exists.")
            return

        raw_api_key = f"pk_live_{secrets.token_urlsafe(32)}"
        partner = Partner(
            id=str(uuid.uuid4()),
            name=name.strip(),
            api_key_hash=hash_api_key(raw_api_key),
            status=PartnerStatus.ACTIVE,
        )
        session.add(partner)
        await session.commit()

        print("\n========================================================")
        print("  MERCHANT PARTNER CREATED SUCCESSFULLY")
        print("========================================================")
        print(f"  Partner ID : {partner.id}")
        print(f"  Name       : {partner.name}")
        print(f"  Status     : {partner.status.value}")
        print(f"  API Key    : {raw_api_key}")
        print("--------------------------------------------------------")
        print("  IMPORTANT: Copy and store this API key now.")
        print("  It will NEVER be displayed again.")
        print("========================================================\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Qadam Administrative CLI")
    subparsers = parser.add_subparsers(dest="command", required=True)

    create_partner_parser = subparsers.add_parser("create-partner", help="Create a new merchant partner")
    create_partner_parser.add_argument("--name", required=True, help="Display name of the merchant")

    args = parser.parse_args()

    if args.command == "create-partner":
        asyncio.run(create_partner_cli(args.name))


if __name__ == "__main__":
    main()
