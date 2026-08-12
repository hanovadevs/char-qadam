"""Application configuration loaded from environment variables."""
from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Central settings object. Values are read from env vars / a .env file."""

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # App
    app_name: str = "Qadam API"
    environment: str = "development"
    debug: bool = True

    # MongoDB
    mongo_uri: str = "mongodb://localhost:27017"
    mongo_db_name: str = "qadam"

    # JWT auth
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 60 * 24  # 24h


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()
