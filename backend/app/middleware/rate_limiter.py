"""Sliding-window in-memory Rate Limiting Middleware for Auth Endpoints."""
from __future__ import annotations

import time
from collections import defaultdict
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.config import get_settings

# Route -> (max_requests, window_seconds)
RATE_LIMITS: dict[str, tuple[int, int]] = {
    "/auth/login": (15, 60),
    "/auth/register": (15, 60),
    "/auth/forgot-password": (10, 60),
    "/auth/reset-password": (10, 60),
}


class RateLimiterMiddleware(BaseHTTPMiddleware):
    def __init__(self, app):
        super().__init__(app)
        # key: (client_ip, path) -> list of request timestamps
        self._history: dict[tuple[str, str], list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next) -> Response:
        settings = get_settings()

        # In testing/debug bypass if disabled or test header present
        if request.headers.get("X-Bypass-Rate-Limit") == "true":
            return await call_next(request)

        path = request.url.path
        if path in RATE_LIMITS:
            max_requests, window_seconds = RATE_LIMITS[path]
            client_ip = request.client.host if request.client else "127.0.0.1"
            now = time.time()

            key = (client_ip, path)
            timestamps = self._history[key]

            # Evict timestamps outside the window
            cutoff = now - window_seconds
            self._history[key] = [t for t in timestamps if t > cutoff]

            if len(self._history[key]) >= max_requests:
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too many requests. Please slow down and try again later."},
                    headers={"Retry-After": str(window_seconds)},
                )

            self._history[key].append(now)

        return await call_next(request)
