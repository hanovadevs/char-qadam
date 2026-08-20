"""FastAPI application entry point for the Qadam backend.

Wires up config, PostgreSQL lifespan, CORS, and a /health endpoint.
Feature routers will be registered here as each backend phase completes.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db.postgres import dispose_engine, get_engine
from app.routers import activity, auth, health, offers, partner, points, users, vouchers


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage startup/shutdown: warm-up and dispose the PostgreSQL engine."""
    # Touch the engine on startup so misconfigured DATABASE_URL fails fast.
    get_engine()
    yield
    await dispose_engine()


def create_app() -> FastAPI:
    """Build and configure the FastAPI application instance."""
    settings = get_settings()
    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],  # Tighten before production.
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(users.router)
    app.include_router(activity.router)
    app.include_router(points.router)
    app.include_router(offers.router)
    app.include_router(vouchers.router)
    app.include_router(partner.router)

    @app.get("/", tags=["root"])
    async def root() -> dict:
        return {"service": settings.app_name, "docs": "/docs", "health": "/health"}

    return app


app = create_app()
