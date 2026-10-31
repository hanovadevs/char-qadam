"""Bounded per-worker auth throttling; use the reverse proxy for a shared limit."""
from __future__ import annotations

import math
import time
from collections import OrderedDict, deque

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.config import get_settings

RATE_LIMITS = {
    "/auth/login": (15, 60),
    "/auth/google": (15, 60),
    "/auth/register": (15, 60),
    "/auth/forgot-password": (10, 60),
    "/auth/reset-password": (10, 60),
    "/admin/auth/login": (10, 60),
}


class RateLimiterMiddleware(BaseHTTPMiddleware):
    max_keys = 10000

    def __init__(self, app):
        super().__init__(app)
        self._history = OrderedDict()

    async def dispatch(self, request: Request, call_next) -> Response:
        if (get_settings().environment.lower() == "test"
                and request.headers.get("X-Bypass-Rate-Limit") == "true"):
            return await call_next(request)
        path = request.url.path.rstrip("/")
        if path not in RATE_LIMITS or request.method != "POST":
            return await call_next(request)
        maximum, window = RATE_LIMITS[path]
        now = time.monotonic()
        key = (request.client.host if request.client else "unknown", path)
        # All windows are 60s; LRU order tracks the most recent request.
        while self._history:
            oldest = next(iter(self._history))
            if self._history[oldest][-1] > now - window:
                break
            self._history.popitem(last=False)
        timestamps = self._history.setdefault(key, deque())
        self._history.move_to_end(key)
        while timestamps and timestamps[0] <= now - window:
            timestamps.popleft()
        if len(timestamps) >= maximum:
            return JSONResponse(
                status_code=429,
                content={"detail": "Too many requests. Please try again later."},
                headers={"Retry-After": str(max(1, math.ceil(timestamps[0] + window - now)))},
            )
        timestamps.append(now)
        while len(self._history) > self.max_keys:
            self._history.popitem(last=False)
        return await call_next(request)
