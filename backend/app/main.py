"""FastAPI application entry point for the Qadam backend.

Wires up config, PostgreSQL lifespan, CORS, Middlewares, and all Feature routers.
"""
from contextlib import asynccontextmanager

from pathlib import Path
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db.postgres import dispose_engine, get_engine
from app.middleware.logging_middleware import StructuredLoggingMiddleware
from app.middleware.rate_limiter import RateLimiterMiddleware
from app.routers import (
    activity,
    admin,
    auth,
    health,
    leaderboard,
    offers,
    partner,
    points,
    users,
    vouchers,
)


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

    # Core middlewares
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.add_middleware(RateLimiterMiddleware)
    app.add_middleware(StructuredLoggingMiddleware)

    # Feature routers
    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(users.router)
    app.include_router(activity.router)
    app.include_router(points.router)
    app.include_router(offers.router)
    app.include_router(vouchers.router)
    app.include_router(partner.router)
    app.include_router(leaderboard.router)
    app.include_router(admin.public_router)
    app.include_router(admin.router)


    # Mount Static Web Admin Portal
    web_dist = Path(__file__).resolve().parents[2] / "web" / "dist"
    if web_dist.is_dir():
        assets_dir = web_dist / "assets"
        if assets_dir.is_dir():
            app.mount("/assets", StaticFiles(directory=str(assets_dir)), name="web_assets")

        @app.get("/favicon.svg", include_in_schema=False)
        async def favicon_svg():
            fav = web_dist / "favicon.svg"
            if fav.is_file():
                return FileResponse(fav)
            return {"detail": "not found"}

        @app.get("/portal", include_in_schema=False)
        @app.get("/portal/{full_path:path}", include_in_schema=False)
        @app.get("/login", include_in_schema=False)
        @app.get("/dashboard", include_in_schema=False)
        @app.get("/stores", include_in_schema=False)
        @app.get("/deals", include_in_schema=False)
        @app.get("/vouchers", include_in_schema=False)
        @app.get("/users", include_in_schema=False)
        @app.get("/ledger", include_in_schema=False)
        @app.get("/audit", include_in_schema=False)
        @app.get("/settings", include_in_schema=False)
        @app.get("/partners", include_in_schema=False)
        @app.get("/offers", include_in_schema=False)
        @app.get("/pos", include_in_schema=False)
        async def serve_admin_portal():
            index_html = web_dist / "index.html"
            if index_html.is_file():
                return FileResponse(index_html)
            return {"detail": "Admin portal build not found"}

    @app.get("/", tags=["root"])
    async def root() -> dict:
        return {"service": settings.app_name, "docs": "/docs", "health": "/health"}

    return app


app = create_app()
