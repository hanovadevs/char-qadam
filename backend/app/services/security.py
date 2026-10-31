"""Security utilities: password hashing, JWT encode/decode, and Google OAuth.

Password hashing
----------------
Uses bcrypt. Never store raw passwords — only call
``hash_password`` on registration and ``verify_password`` on login.

JWT
---
Tokens are signed HS256 with ``settings.jwt_secret``.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import hashlib
import hmac
import httpx
import jwt
from jwt import InvalidTokenError as JWTError
# pyrefly: ignore [missing-import]
import bcrypt

from app.config import get_settings

# One shared bcrypt context — bcrypt auto-selects a cost factor.



# ---------------------------------------------------------------------------
# Password helpers
# ---------------------------------------------------------------------------

def hash_password(plain: str) -> str:
    """Return bcrypt hash of *plain* suitable for storing in the DB."""
    encoded = plain.encode('utf-8')
    if len(encoded) > 72:
        raise ValueError('Password must be at most 72 UTF-8 bytes')
    return bcrypt.hashpw(encoded, bcrypt.gensalt()).decode('ascii')


def verify_password(plain: str, hashed: str) -> bool:
    """Return True if *plain* matches the stored *hashed* password."""
    try:
        encoded = plain.encode('utf-8')
        if len(encoded) > 72:
            return False
        return bcrypt.checkpw(encoded, hashed.encode('ascii'))
    except (ValueError, UnicodeError):
        return False


# ---------------------------------------------------------------------------
# JWT helpers
# ---------------------------------------------------------------------------

def create_access_token(
    user_id: str | None = None,
    *,
    subject: str | None = None,
    extra_claims: dict[str, Any] | None = None,
    expires_minutes: int | None = None,
) -> str:
    """Mint a signed JWT for *user_id* or *subject* with configured expiry and optional claims."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    sub = user_id or subject or 'anonymous'
    payload: dict[str, Any] = {
        'sub': str(sub),
        'type': 'access',
        'iat': now,
        'exp': now + timedelta(minutes=expires_minutes if expires_minutes is not None else settings.access_token_expire_minutes),
    }
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)



def password_fingerprint(password_hash: str) -> str:
    return hashlib.sha256(password_hash.encode()).hexdigest()[:32]


def create_user_access_token(user) -> str:
    return create_access_token(user.id, extra_claims={
        "role": user.role, "partner_id": user.partner_id,
        "pwd": password_fingerprint(user.password_hash),
    })


def validate_user_token(token: str, user) -> None:
    settings = get_settings()
    claims = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    fingerprint = claims.get("pwd")
    # Legacy development tokens remain supported; production requires revocation binding.
    if fingerprint is None and settings.environment.lower() != "production":
        return
    if not isinstance(fingerprint, str) or not hmac.compare_digest(fingerprint, password_fingerprint(user.password_hash)):
        raise JWTError("Credentials have changed; please sign in again")


def decode_access_token(token: str) -> str:
    """Decode and validate *token*; return the ``sub`` (user_id) on success.

    Raises ``jwt.InvalidTokenError`` if the token is invalid or expired — callers
    should catch this and return 401.
    """
    settings = get_settings()
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != "access":
        raise JWTError("Invalid token type")
    user_id: str | None = payload.get("sub")
    if user_id is None:
        raise JWTError("Token payload missing 'sub' claim")
    return user_id


def create_password_reset_token(user_id: str) -> str:
    """Mint a signed JWT for password reset that expires in 15 minutes."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "type": "password_reset",
        "iat": now,
        "exp": now + timedelta(minutes=15),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_password_reset_token(token: str) -> str:
    """Validate password reset token and return the user_id."""
    settings = get_settings()
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != "password_reset":
        raise JWTError("Invalid token type for password reset")
    user_id: str | None = payload.get("sub")
    if not user_id:
        raise JWTError("Token payload missing 'sub' claim")
    return user_id


# ---------------------------------------------------------------------------
# Google OAuth Verification
# ---------------------------------------------------------------------------

async def verify_google_id_token(id_token: str, client_id: str | None = None) -> dict[str, Any]:
    """Verify Google OAuth ID token.

    Supports:
    1. Deterministic dev/test fallback if token starts with 'mock_google_token:'
    2. Real Google token verification via Google's tokeninfo endpoint.
    """
    settings = get_settings()
    if settings.environment.lower() == "production" and not client_id:
        raise ValueError("Google OAuth is unavailable until GOOGLE_CLIENT_ID is configured")
    if id_token.startswith("mock_google_token:"):
        if settings.environment.lower() != "test":
            raise ValueError("Mock Google tokens are only allowed in test environments")
        email = id_token.split(":", 1)[1]
        return {"email": email, "sub": f"google_{email}"}

    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            "https://oauth2.googleapis.com/tokeninfo",
            params={"id_token": id_token},
        )
        if resp.status_code != 200:
            raise ValueError("Invalid or expired Google ID Token")
        data = resp.json()

        # Verify audience if client_id is configured
        if client_id and data.get("aud") != client_id:
            raise ValueError("Google ID token audience mismatch")

        email = data.get("email")
        if not email or str(data.get("email_verified", "false")).lower() != "true":
            raise ValueError("Google token does not contain an email address")

        return {
            "email": email,
            "sub": data.get("sub", email),
            "email_verified": str(data.get("email_verified", "true")).lower() == "true",
        }

