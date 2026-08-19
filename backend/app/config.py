"""Application configuration loaded from environment variables."""
from functools import lru_cache

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central settings object. Values are read from env vars / a .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    app_name: str = "Qadam API"
    environment: str = "development"
    debug: bool = True

    # PostgreSQL (async)
    # Accepts both postgresql:// and postgresql+asyncpg:// — the validator below
    # normalises plain postgresql:// (psycopg2) to asyncpg automatically.
    database_url: str = "postgresql+asyncpg://qadam:qadam@localhost:5432/qadam"

    @field_validator("database_url", mode="before")
    @classmethod
    def _coerce_asyncpg_scheme(cls, v: str) -> str:
        """Upgrade postgresql:// → postgresql+asyncpg:// if needed."""
        if isinstance(v, str) and v.startswith("postgresql://"):
            return v.replace("postgresql://", "postgresql+asyncpg://", 1)
        return v

    # Points engine — server-side earning rule
    steps_per_point: int = 100          # 100 steps = 1 point
    daily_step_cap: int = 20_000        # max eligible steps counted per day

    # Vouchers
    voucher_validity_days: int = 30     # days from issuance until a voucher expires

    # Partner API (B4)
    # Secret used to HMAC-sign validate→redeem nonces.  Defaults to jwt_secret.
    partner_nonce_secret: str = ""      # if empty, falls back to jwt_secret at runtime
    nonce_max_age_seconds: int = 300    # 5 minutes — nonce window between validate and redeem

    # OAuth (Google / Supabase)
    google_client_id: str = ""
    google_client_secret: str = ""

    # JWT auth
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24 * 365  # 1 year (persistent login)


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
