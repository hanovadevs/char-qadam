"""Health-check router. The only functional endpoint in the scaffold."""
from datetime import datetime, timezone

from fastapi import APIRouter

from app.config import get_settings

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict:
    """Return a simple liveness payload used to verify the app is up."""
    settings = get_settings()
    return {
        "status": "ok",
        "service": settings.app_name,
        "environment": settings.environment,
        "time": datetime.now(timezone.utc).isoformat(),
    }
