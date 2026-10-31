"""Security utilities: password hashing, JWT encode/decode, and Google OAuth.

Password hashing
----------------
Uses passlib's bcrypt handler. Never store raw passwords — only call
``hash_password`` on registration and ``verify_password`` on login.

JWT
---
Tokens are signed HS256 with ``settings.jwt_secret``.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import hmac
from typing import Any

import httpx
import jwt
from jwt import InvalidTokenError as JWTError
# pyrefly: ignore [missing-import]
from passlib.context import CryptContext

from app.config import get_settings

# One shared bcrypt context — bcrypt auto-selects a cost factor.
_pwd_context = CryptContext(schemes=["bcrypt_sha256", "bcrypt"], deprecated="auto")


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

def create_access_token(
    user_id: str | None = None,
    *,
    subject: str | None = None,
    extra_claims: dict[str, Any] | None = None,
) -> str:
    """Mint a signed JWT for *user_id* or *subject* with configured expiry and optional claims."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    sub = user_id or subject or 'anonymous'
    payload: dict[str, Any] = {
        'sub': str(sub),
        'type': 'access',
        'iat': now,
        'exp': now + timedelta(minutes=settings.access_token_expire_minutes),
    }
    if extra_claims:
        payload.update(extra_claims)
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_access_claims(token: str) -> dict[str, Any]:
    settings = get_settings()
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get('type') != 'access' or not payload.get('sub'):
        raise JWTError('Invalid access token type or subject')
    return payload


def decode_access_token(token: str) -> str:
    """Decode and validate *token*; return the ``sub`` (user_id) on success.

    Raises ``jose.JWTError`` if the token is invalid or expired — callers
    should catch this and return 401.
    """
    payload = decode_access_claims(token)
    user_id: str | None = payload.get("sub")
    if user_id is None:
        raise JWTError("Token payload missing 'sub' claim")
    return user_id


def _password_fingerprint(password_hash: str) -> str:
    return hmac.new(get_settings().jwt_secret.encode(), password_hash.encode(), hashlib.sha256).hexdigest()


def create_password_reset_token(user_id: str, password_hash: str, *, email: str = '', auth_version: int = 0) -> str:
    """Mint a signed JWT for password reset that expires in 15 minutes."""
    settings = get_settings()
    now = datetime.now(timezone.utc)
    payload = {
        "sub": user_id,
        "type": "password_reset",
        "password_fingerprint": _password_fingerprint(password_hash),
        "email": email,
        "ver": auth_version,
        "iat": now,
        "exp": now + timedelta(minutes=15),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_password_reset_token(token: str, password_hash: str | None = None, *, email: str | None = None, auth_version: int | None = None) -> str:
    """Validate password reset token and return the user_id."""
    settings = get_settings()
    payload = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if payload.get("type") != "password_reset":
        raise JWTError("Invalid token type for password reset")
    if ((email is not None and payload.get('email') != email)
            or (auth_version is not None and payload.get('ver') != auth_version)):
        raise JWTError('Password reset token has been invalidated')
    if password_hash is not None and not hmac.compare_digest(
        payload.get('password_fingerprint', ''), _password_fingerprint(password_hash)
    ):
        raise JWTError('Password reset token has already been used or invalidated')
    user_id: str | None = payload.get("sub")
    if not user_id:
        raise JWTError("Token payload missing 'sub' claim")
    return user_id


# ---------------------------------------------------------------------------
# Google OAuth Verification
# ---------------------------------------------------------------------------

async def verify_google_id_token(id_token: str, client_id: str | None = None) -> dict[str, Any]:
    """Verify with Google and require the configured audience and verified email."""
    if not client_id or id_token.startswith('mock_google_token:'):
        raise ValueError('Google sign-in is unconfigured or token is invalid')

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
        if not email:
            raise ValueError("Google token does not contain an email address")
        if str(data.get('email_verified', 'false')).lower() != 'true':
            raise ValueError('Google email address is not verified')
        if data.get('iss') not in ('accounts.google.com', 'https://accounts.google.com') or not data.get('sub'):
            raise ValueError('Invalid Google token issuer or subject')

        return {
            "email": email,
            "sub": data.get("sub", email),
            "email_verified": str(data.get("email_verified", "true")).lower() == "true",
            "authoritative_email": email.lower().endswith('@gmail.com') or bool(data.get('hd')),
        }

