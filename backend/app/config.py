"""Application configuration loaded from environment variables."""
from functools import lru_cache
from typing import Union

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central settings object. Values are read from env vars / a .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    app_name: str = "Stepsy API"
    environment: str = "development"
    debug: bool = True

    # CORS Configuration
    # Accepts comma-separated string (e.g. "https://stepsy.app,https://admin.stepsy.app") or list
    cors_origins: Union[str, list[str]] = ["*"]

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _parse_cors_origins(cls, v: Union[str, list[str]]) -> list[str]:
        if isinstance(v, str):
            if v.strip() == "*":
                return ["*"]
            return [origin.strip() for origin in v.split(",") if origin.strip()]
        return v

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

    @model_validator(mode="after")
    def _validate_production_invariants(self) -> "Settings":
        """Enforce strict security requirements when deployed in production."""
        if self.environment.lower() == "production":
            if self.jwt_secret in ("change-me-in-production", "secret", "test-secret") or len(self.jwt_secret) < 32:
                raise ValueError(
                    "CRITICAL: Production deployment requires a secure JWT_SECRET with at least 32 characters! "
                    "Generate one with: python -c 'import secrets; print(secrets.token_hex(32))'"
                )
            if self.debug is True:
                # Force debug mode off in production
                object.__setattr__(self, "debug", False)
        return self


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
