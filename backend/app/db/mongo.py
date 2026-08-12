"""MongoDB connection handling using the Motor async driver.

No collections or documents are defined yet — this only wires up the
client/lifespan so feature work can attach later.
"""
from __future__ import annotations

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import get_settings


class _MongoState:
    """Holds the process-wide Motor client and database handle."""

    client: AsyncIOMotorClient | None = None
    db: AsyncIOMotorDatabase | None = None


mongo = _MongoState()


async def connect_to_mongo() -> None:
    """Open the Motor client. Called on application startup."""
    settings = get_settings()
    mongo.client = AsyncIOMotorClient(settings.mongo_uri)
    mongo.db = mongo.client[settings.mongo_db_name]


async def close_mongo_connection() -> None:
    """Close the Motor client. Called on application shutdown."""
    if mongo.client is not None:
        mongo.client.close()
        mongo.client = None
        mongo.db = None


def get_db() -> AsyncIOMotorDatabase:
    """Return the active database handle (raises if not connected)."""
    if mongo.db is None:
        raise RuntimeError("MongoDB is not connected. Did startup run?")
    return mongo.db
