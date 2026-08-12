"""FastAPI application entry point for the Qadam backend.

Scaffold only: wires up config, MongoDB lifespan, CORS, and a /health
endpoint. No feature routers are registered yet.
"""
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db.mongo import close_mongo_connection, connect_to_mongo
from app.routers import health


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage startup/shutdown: open and close the MongoDB connection."""
    await connect_to_mongo()
    yield
    await close_mongo_connection()


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

    @app.get("/", tags=["root"])
    async def root() -> dict:
        return {"service": settings.app_name, "docs": "/docs", "health": "/health"}

    return app


app = create_app()
