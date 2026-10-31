"""Purpose-limited challenges; codes never leave the mail transport or become JWTs."""
import asyncio
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import secrets

from fastapi import HTTPException
import jwt
from jwt import InvalidTokenError as JWTError

from app.config import get_settings
from app.db.models import User
from app.schemas.auth import VerificationOut
from app.services.email import send_verification_email


def requires_email_verification(user: User) -> bool:
    """Managed store login IDs are not mailboxes; never exempt public signups.

    Only administrators can assign MERCHANT and link a store. Keep the actual
    mailbox-proof timestamp empty instead of claiming an inbox was verified.
    """
    managed_store_login = (
        user.role == 'MERCHANT'
        and bool(user.partner_id)
        and user.email.rpartition('@')[2].lower() == 'stepsyapp.com'
    )
    return user.email_verified_at is None and not managed_store_login


def code_hash(user: User, code: str) -> str:
    value = f'email-verification:{user.id}:{user.auth_version}:{code}'
    return hmac.new(get_settings().jwt_secret.encode(), value.encode(), hashlib.sha256).hexdigest()


def decode_challenge(token: str) -> dict:
    settings = get_settings()
    claims = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if claims.get('type') != 'email_verification' or not claims.get('sub'):
        raise JWTError('Invalid verification challenge')
    return claims


def clear_code(user: User) -> None:
    user.verification_code_hash = None
    user.verification_expires_at = None
    user.verification_attempts = 0


def change_email(user: User, email: str) -> None:
    """Ownership proof and provider links never transfer to a different mailbox."""
    email = email.strip().lower()
    if user.email == email:
        return
    user.email = email
    user.email_verified_at = None
    user.google_subject = None
    user.verification_sent_at = None
    clear_code(user)
    user.auth_version += 1


async def challenge(user: User, *, device_id: str, google_subject: str | None = None, force_send: bool = False) -> VerificationOut:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    remaining = max(0, 60 - int((now - user.verification_sent_at).total_seconds())) if user.verification_sent_at else 0
    if force_send and remaining:
        raise HTTPException(429, 'Please wait before requesting another code.', headers={'Retry-After': str(remaining)})
    if not remaining:
        if not settings.smtp_host or not settings.smtp_from:
            raise HTTPException(503, 'Email verification is temporarily unavailable. Please try again later.')
        code = f'{secrets.randbelow(1_000_000):06d}'
        try:
            await asyncio.to_thread(send_verification_email, user.email, code, settings)
        except Exception:
            raise HTTPException(503, 'Could not send the verification email. Please try again later.')
        user.verification_code_hash = code_hash(user, code)
        user.verification_expires_at = now + timedelta(minutes=10)
        user.verification_sent_at = now
        user.verification_attempts = 0
        remaining = 60
    claims = {'sub': user.id, 'type': 'email_verification', 'ver': user.auth_version, 'did': device_id,
              'iat': now, 'exp': now + timedelta(minutes=30)}
    if google_subject:
        claims['google_sub'] = google_subject
    return VerificationOut(
        verification_token=jwt.encode(claims, settings.jwt_secret, algorithm=settings.jwt_algorithm),
        email=user.email, resend_after_seconds=remaining,
    )
