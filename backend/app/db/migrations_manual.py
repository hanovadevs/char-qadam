import asyncio
import secrets
import asyncpg
from app.services.security import hash_password
from app.config import get_settings

DATABASE_URL = get_settings().database_url.replace("postgresql+asyncpg://", "postgresql://", 1)

async def migrate():
    print("Connecting to Supabase PostgreSQL database...")
    conn = await asyncpg.connect(DATABASE_URL)

    print("Adding 'role' and 'partner_id' to public.users...")
    await conn.execute("""
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role VARCHAR(32) DEFAULT 'USER';
        ALTER TABLE public.users ADD COLUMN IF NOT EXISTS partner_id VARCHAR(36) REFERENCES public.partners(id) ON DELETE SET NULL;
        CREATE INDEX IF NOT EXISTS idx_users_partner_id ON public.users(partner_id);
    """)
    print("Schema updated successfully.")

    # Check existing partners and ensure each has a matching User record
    partners = await conn.fetch("SELECT id, name, email, password_hash FROM public.partners;")
    print(f"Found {len(partners)} existing partners in database.")

    default_hash = hash_password(secrets.token_urlsafe(32))

    for p in partners:
        p_id = p['id']
        p_name = p['name']
        p_email = p['email']
        p_hash = p['password_hash'] or default_hash

        if not p_email:
            # Generate a clean email based on partner name or id
            clean_name = "".join(c for c in p_name.lower() if c.isalnum()) or "merchant"
            p_email = f"{clean_name}_{p_id[:4]}@stepsy.app"
            await conn.execute("UPDATE public.partners SET email = $1 WHERE id = $2;", p_email, p_id)
            print(f"Assigned email {p_email} to partner '{p_name}'")

        # Check if user with this email exists
        existing_user = await conn.fetchrow("SELECT id FROM public.users WHERE email = $1;", p_email)
        if existing_user:
            await conn.execute("""
                UPDATE public.users
                SET role = 'MERCHANT', partner_id = $1
                WHERE email = $2;
            """, p_id, p_email)
            print(f"Updated user {p_email} to role='MERCHANT', partner_id='{p_id}'")
        else:
            import uuid
            user_id = str(uuid.uuid4())
            await conn.execute("""
                INSERT INTO public.users (id, email, password_hash, status, role, partner_id)
                VALUES ($1, $2, $3, 'ACTIVE', 'MERCHANT', $4);
            """, user_id, p_email, p_hash, p_id)
            print(f"Created new merchant user {p_email} for partner '{p_name}' (reset the merchant password in the admin panel)")

    await conn.close()
    print("Migration and backfill completed successfully!")

if __name__ == "__main__":
    asyncio.run(migrate())
