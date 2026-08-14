"""Security utilities: password hashing and JWT encode/decode.

Password hashing
----------------
Uses passlib's bcrypt handler.  Never store raw passwords — only call
``hash_password`` on registration and ``verify_password`` on login.

JWT
---
Tokens are signed HS256 with ``settings.jwt_secret``.  The payload carries:
    sub   : user UUID (string)
    exp   : expiry timestamp (UTC)
    iat   : issued-at timestamp (UTC)

Callers should use ``create_access_token`` and ``decode_access_token``.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import get_settings

# One shared bcrypt context — bcrypt auto-selects a cost factor.
_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


# ---------------------------------------------------------------------------
# Password helpers
# ---------------------------------------------------------------------------

def hash_password(plain: str) -> str:
    """Return bcrypt hash of *plain* suitable for storing in the DB."""
    return _pwd_context.hash(plain)


def verify_password(plain: str, hashed: str) -> bool:
    """Return True if *plain* matches the stored *hashed* password."""
    return _pwd_context.verify(plain, hashed)


# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------

def create_access_token(user_id: str) -> str:
    """Mint a signed JWT for *user_id* with the configured expiry."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_expire_minutes),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_token(token: str) -> str:
    """Decode and validate *token*; return the ``sub`` (user_id) on success.

    Raises ``jose.JWTError`` if the token is invalid or expired — callers
    should catch this and return 401.
    """
    settings = get_settings()
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    user_id: str | None = payload.get("sub")
    if user_id is None:
        raise JWTError("Token payload missing 'sub' claim")
    return user_id
