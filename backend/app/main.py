"""FastAPI application entry point for the Qadam backend.

Wires up config, PostgreSQL lifespan, CORS, Middlewares, and all Feature routers.
"""
from contextlib import asynccontextmanager
import httpx

from pathlib import Path
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.db.postgres import dispose_engine, warm_pool, warm_read_pool
from app.middleware.logging_middleware import StructuredLoggingMiddleware
from app.middleware.rate_limiter import RateLimiterMiddleware
from app.services.store_cover import cover_path
from app.routers import (
    activity,
    admin,
    auth,
    health,
    leaderboard,
    offers,
    partner,
    partner_ledgers,
    support,
    points,
    users,
    vouchers,
)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage startup/shutdown: warm-up and dispose the PostgreSQL engine."""
    try:
        await warm_pool()
        await warm_read_pool()
        async with httpx.AsyncClient(timeout=12.0, limits=httpx.Limits(max_connections=10, max_keepalive_connections=5)) as client:
            app.state.support_ai_client = client
            yield
    finally:
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

    @app.get('/privacy', include_in_schema=False)
    @app.get('/privacy.html', include_in_schema=False)
    async def privacy_policy():
        return FileResponse(Path(__file__).parent / 'public' / 'privacy.html',
                            media_type='text/html', headers={'X-Content-Type-Options': 'nosniff'})

    @app.get('/delete-account', include_in_schema=False)
    @app.get('/delete-account.html', include_in_schema=False)
    async def deletion_policy():
        return FileResponse(Path(__file__).parent / 'public' / 'delete-account.html',
                            media_type='text/html', headers={'X-Content-Type-Options': 'nosniff'})

    # Feature routers
    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(users.router)
    app.include_router(activity.router)
    app.include_router(points.router)
    app.include_router(offers.router)
    app.include_router(vouchers.router)
    app.include_router(partner.router)
    app.include_router(partner_ledgers.router)
    app.include_router(leaderboard.router)
    app.include_router(admin.public_router)
    app.include_router(admin.router)
    app.include_router(support.router)
    app.include_router(support.admin_router)

    @app.get('/media/store-covers/{filename}', include_in_schema=False)
    async def store_cover(filename: str):
        image = cover_path(filename, get_settings())
        if not image.is_file():
            raise HTTPException(404, 'Cover not found')
        return FileResponse(image, media_type='image/webp', headers={
            'Cache-Control': 'public, max-age=31536000, immutable',
            'X-Content-Type-Options': 'nosniff',
        })


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
        @app.get("/support", include_in_schema=False)
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
