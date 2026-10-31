"""Structured JSON Request Logging Middleware with Sensitive Header Redaction."""
from __future__ import annotations

import json
import logging
import time
import uuid
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

logger = logging.getLogger("qadam.access")

SENSITIVE_HEADERS = {"authorization", "x-partner-key", "cookie", "set-cookie"}


class StructuredLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        start_time = time.perf_counter()

        client_ip = request.client.host if request.client else "unknown"
        method = request.method
        path = request.url.path

        response: Response
        try:
            response = await call_next(request)
        except Exception as exc:
            duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
            log_payload = {
                "request_id": request_id,
                "client_ip": client_ip,
                "method": method,
                "path": path,
                "status_code": 500,
                "duration_ms": duration_ms,
                "error": str(exc),
            }
            logger.error(json.dumps(log_payload))
            raise exc

        duration_ms = round((time.perf_counter() - start_time) * 1000, 2)
        response.headers["X-Request-ID"] = request_id

        # Skip spamming logs for standard root or health checks in development
        if path not in ("/health", "/"):
            log_payload = {
                "request_id": request_id,
                "client_ip": client_ip,
                "method": method,
                "path": path,
                "status_code": response.status_code,
                "duration_ms": duration_ms,
            }
            logger.info(json.dumps(log_payload))

        return response
