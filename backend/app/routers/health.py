"""Health and readiness probes for container orchestration and load balancers."""
import time
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.postgres import get_session

router = APIRouter(tags=["health"])


@router.get("/health", summary="Basic liveness probe")
async def health_live() -> dict:
    """Lightweight liveness probe checking that the application process is alive."""
    settings = get_settings()
    return {
        "status": "ok",
        "service": settings.app_name,
        "environment": settings.environment,
        "time": datetime.now(timezone.utc).isoformat(),
    }


@router.get("/health/ready", summary="Deep readiness probe")
async def health_ready(session: AsyncSession = Depends(get_session)) -> dict:
    """Deep readiness probe verifying PostgreSQL database connectivity and measuring latency."""
    settings = get_settings()
    start_time = time.perf_counter()

    try:
        # Ping the database
        await session.execute(text("SELECT 1"))
        latency_ms = round((time.perf_counter() - start_time) * 1000, 2)

        return {
            "status": "ready",
            "service": settings.app_name,
            "environment": settings.environment,
            "database": {
                "status": "connected",
                "latency_ms": latency_ms,
            },
            "time": datetime.now(timezone.utc).isoformat(),
        }
    except Exception as e:
        latency_ms = round((time.perf_counter() - start_time) * 1000, 2)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={
                "status": "unhealthy",
                "service": settings.app_name,
                "database": {
                    "status": "error",
                    "latency_ms": latency_ms,
                    "error": str(e),
                },
                "time": datetime.now(timezone.utc).isoformat(),
            },
        )
