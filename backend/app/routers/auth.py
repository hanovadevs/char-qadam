"""Auth router — registration, login, password recovery, and current-user endpoints.

Routes
------
POST /auth/register         Create an account and send an email code.
POST /auth/verify-email     Verify a single-use email code, then issue a JWT.
POST /auth/resend-verification Resend an email code after cooldown.
POST /auth/login            Authenticate with email+password; returns a JWT.
POST /auth/google           Authenticate via Google OAuth ID Token; returns a JWT.
POST /auth/forgot-password  Request a signed password reset token.
POST /auth/reset-password   Reset password with valid reset token.
GET  /auth/me               Return the authenticated user's profile.
"""
from __future__ import annotations

import asyncio
import uuid
import hmac
import httpx
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.db.models import Partner, User, UserStatus
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.auth import (
    ForgotPasswordIn,
    ForgotPasswordOut,
    GoogleAuthIn,
    LoginIn,
    RegisterIn,
    ResetPasswordIn,
    ResetPasswordOut,
    TokenOut,
    UserOut,
    VerificationOut, VerifyEmailIn, ResendVerificationIn,
)
from app.services.email_verification import challenge, clear_code, code_hash, decode_challenge, requires_email_verification
from app.services.device_binding import require_device_key, claim_device, check_device_available
from app.services.security import (
    create_access_token,
    create_password_reset_token,
    decode_password_reset_token,
    hash_password,
    verify_google_id_token,
    verify_password,
)
from app.services.email import send_password_reset_email

router = APIRouter(prefix="/auth", tags=["auth"])


async def _token(user: User, session: AsyncSession, key: str) -> TokenOut:
    binding = await claim_device(key, user, session)
    await session.commit()
    partner = await session.get(Partner, user.partner_id) if user.partner_id else None
    return TokenOut(
        access_token=create_access_token(user.id, extra_claims={
            'role': user.role, 'partner_id': user.partner_id, 'ver': user.auth_version,
            'did': binding.id, 'dgen': binding.generation,
        }), role=user.role, partner_id=user.partner_id,
        partner_name=partner.name if partner else None,
        user=_user_out(user, partner.name if partner else None),
    )


@router.post(
    "/register",
    response_model=VerificationOut,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account",
)
async def register(
    body: RegisterIn,
    key: str = Depends(require_device_key),
    session: AsyncSession = Depends(get_session),
) -> VerificationOut:
    """Create an unverified account and send a mailbox challenge.

    Returns **409** if the email is already registered.
    """
    # Check for duplicate email
    existing = await session.execute(
        select(User).where(User.email == body.email)
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    user = User(
        id=str(uuid.uuid4()),
        email=body.email,
        password_hash=hash_password(body.password),
        status=UserStatus.ACTIVE,
        country=body.country,
        timezone=body.timezone,
    )
    await check_device_available(key, user.id, session)
    session.add(user)
    try:
        await session.flush()
        response = await challenge(user, device_id=key)
        await session.commit()
    except IntegrityError:
        await session.rollback()
        raise HTTPException(409, 'An account with this email already exists')
    return response


@router.post(
    "/login",
    response_model=TokenOut | VerificationOut,
    summary="Log in and receive a JWT",
)
async def login(
    body: LoginIn,
    key: str = Depends(require_device_key),
    session: AsyncSession = Depends(get_session),
) -> TokenOut | VerificationOut:
    """Authenticate with email + password.

    Returns **401** on invalid credentials (deliberately vague to prevent
    email enumeration).
    """
    result = await session.execute(
        select(User).where(User.email == body.email).with_for_update()
    )
    user = result.scalar_one_or_none()

    if user is None or not await asyncio.to_thread(verify_password, body.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is suspended or deleted",
        )

    await check_device_available(key, user.id, session)
    if requires_email_verification(user):
        response = await challenge(user, device_id=key)
        await session.commit()
        return response

    return await _token(user, session, key)


@router.post(
    "/google",
    response_model=TokenOut | VerificationOut,
    summary="Authenticate via Google OAuth ID Token",
)
async def google_auth(
    body: GoogleAuthIn,
    key: str = Depends(require_device_key),
    session: AsyncSession = Depends(get_session),
) -> TokenOut | VerificationOut:
    """Exchange a Google OAuth ID Token for a Qadam JWT.

    If the user does not exist in the system, a new account is automatically
    created. If the account exists, it is logged in.

    Returns **401** if the Google token is invalid or unverified.
    """
    settings = get_settings()
    if not settings.google_client_id:
        raise HTTPException(503, 'Google sign-in is temporarily unavailable.')
    try:
        verified_info = await verify_google_id_token(
            body.id_token,
            client_id=settings.google_client_id if settings.google_client_id else None,
        )
        email = str(verified_info.get("email") or '').lower()
    except httpx.HTTPError:
        raise HTTPException(503, 'Could not reach Google. Please try again.')
    except Exception:
        email = None

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or unverified Google ID Token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # The stable Google subject is the identity; email is only used for first linking.
    subject = verified_info['sub']
    result = await session.execute(select(User).where(User.google_subject == subject).with_for_update())
    user = result.scalar_one_or_none()
    bound = user is not None
    if user is None:
        result = await session.execute(select(User).where(User.email == email).with_for_update())
        user = result.scalar_one_or_none()
        if user and user.google_subject and user.google_subject != subject:
            raise HTTPException(409, 'This email is linked to a different Google account. Please contact support.')
    if user is None:
        # Auto-register new user
        user = User(
            id=str(uuid.uuid4()),
            email=email,
            password_hash=hash_password(f"GoogleOAuth:{uuid.uuid4()}"),
            status=UserStatus.ACTIVE,
            country=body.country,
            timezone=body.timezone,
        )
        session.add(user)
        try:
            await session.flush()
        except IntegrityError:
            await session.rollback()
            raise HTTPException(409, 'Account creation is already in progress. Please sign in again.')
    else:
        if user.status != UserStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is suspended or deleted",
            )

    await check_device_available(key, user.id, session)
    if not bound and not verified_info.get('authoritative_email', False):
        response = await challenge(user, device_id=key, google_subject=subject)
        await session.commit()
        return response
    if user.email_verified_at is None:
        # Prevent a password planted before mailbox verification from remaining usable.
        user.password_hash = hash_password(f'GoogleOAuth:{uuid.uuid4()}')
        user.auth_version += 1
        user.email_verified_at = datetime.now(timezone.utc)
    user.google_subject = subject
    clear_code(user)
    try:
        return await _token(user, session, key)
    except IntegrityError:
        await session.rollback()
        raise HTTPException(409, 'Google account link has changed. Please sign in again.')


async def _challenge_user(token: str, session: AsyncSession, key: str) -> tuple[User, dict]:
    try:
        claims = decode_challenge(token)
        if claims.get('did') != key:
            raise ValueError('Verification belongs to another device')
    except Exception:
        raise HTTPException(400, 'Verification expired. Please sign in again to request a new code.')
    user = await session.scalar(select(User).where(User.id == claims['sub']).with_for_update())
    if user is None or user.status != UserStatus.ACTIVE or user.auth_version != claims.get('ver'):
        raise HTTPException(400, 'Verification expired. Please sign in again.')
    if user.email_verified_at is not None and not claims.get('google_sub'):
        raise HTTPException(400, 'Email already verified. Please sign in.')
    await check_device_available(key, user.id, session)
    return user, claims


@router.post('/verify-email', response_model=TokenOut)
async def verify_email(body: VerifyEmailIn, key: str = Depends(require_device_key), session: AsyncSession = Depends(get_session)) -> TokenOut:
    user, claims = await _challenge_user(body.verification_token, session, key)
    if (not user.verification_code_hash or not user.verification_expires_at
            or user.verification_expires_at <= datetime.now(timezone.utc)):
        raise HTTPException(400, 'Code expired. Please request a new code.')
    if user.verification_attempts >= 5:
        raise HTTPException(429, 'Too many incorrect codes. Request a new code after the resend timer.')
    if not hmac.compare_digest(code_hash(user, body.code), user.verification_code_hash):
        user.verification_attempts += 1
        await session.commit()  # Failed attempts must survive the HTTP error/transaction rollback.
        raise HTTPException(400, 'Incorrect verification code.')
    if subject := claims.get('google_sub'):
        if user.google_subject and user.google_subject != subject:
            raise HTTPException(409, 'Google account link has changed. Please sign in again.')
        if user.email_verified_at is None:
            user.password_hash = hash_password(f'GoogleOAuth:{uuid.uuid4()}')
        user.google_subject = subject
    user.email_verified_at = user.email_verified_at or datetime.now(timezone.utc)
    user.auth_version += 1
    clear_code(user)
    return await _token(user, session, key)


@router.post('/resend-verification', response_model=VerificationOut)
async def resend_verification(body: ResendVerificationIn, key: str = Depends(require_device_key), session: AsyncSession = Depends(get_session)) -> VerificationOut:
    user, claims = await _challenge_user(body.verification_token, session, key)
    response = await challenge(user, device_id=key, google_subject=claims.get('google_sub'), force_send=True)
    await session.commit()
    return response


@router.post(
    "/forgot-password",
    response_model=ForgotPasswordOut,
    summary="Request a password reset token",
)
async def forgot_password(
    body: ForgotPasswordIn,
    session: AsyncSession = Depends(get_session),
) -> ForgotPasswordOut:
    """Request a password reset token for the given email address.

    Returns 200 regardless of whether the email exists to prevent enumeration.
    """
    settings = get_settings()
    if not settings.smtp_host or not settings.smtp_from:
        raise HTTPException(status_code=503, detail='Password recovery is temporarily unavailable. Please contact support.')
    result = await session.execute(
        select(User).where(User.email == body.email)
    )
    user = result.scalar_one_or_none()

    reset_token: str | None = None
    if user is not None and user.status == UserStatus.ACTIVE:
        reset_token = create_password_reset_token(user.id, user.password_hash, email=user.email, auth_version=user.auth_version)
        try:
            await asyncio.to_thread(send_password_reset_email, user.email, reset_token, settings)
        except Exception:
            raise HTTPException(status_code=503, detail='Password recovery is temporarily unavailable. Please try again later.')

    return ForgotPasswordOut(
        message="If this email is registered, password reset instructions have been sent.",
    )


@router.post(
    "/reset-password",
    response_model=ResetPasswordOut,
    summary="Reset password using a valid reset token",
)
async def reset_password(
    body: ResetPasswordIn,
    session: AsyncSession = Depends(get_session),
) -> ResetPasswordOut:
    """Reset user password using a verified reset token."""
    try:
        user_id = decode_password_reset_token(body.reset_token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired password reset token",
        )

    result = await session.execute(
        select(User).where(User.id == user_id).with_for_update()
    )
    user = result.scalar_one_or_none()

    if user is None or user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found or account is inactive",
        )

    try:
        decode_password_reset_token(body.reset_token, user.password_hash, email=user.email, auth_version=user.auth_version)
    except Exception:
        raise HTTPException(status_code=400, detail='Invalid or expired password reset token')
    user.password_hash = hash_password(body.new_password)
    user.auth_version += 1
    user.email_verified_at = user.email_verified_at or datetime.now(timezone.utc)
    clear_code(user)
    await session.commit()

    return ResetPasswordOut(
        message="Password has been successfully updated. Please log in with your new credentials."
    )


@router.get(
    "/me",
    response_model=UserOut,
    summary="Return the currently authenticated user",
)
async def me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> UserOut:
    """Return the profile of the bearer-token owner."""
    partner_name = None
    if current_user.partner_id:
        partner = await session.get(Partner, current_user.partner_id)
        if partner:
            partner_name = partner.name

    return _user_out(current_user, partner_name)


def _user_out(current_user: User, partner_name: str | None) -> UserOut:
    status_val = current_user.status.value if hasattr(current_user.status, "value") else str(current_user.status)
    return UserOut(
        id=current_user.id,
        email=current_user.email,
        status=status_val,
        role=current_user.role or "USER",
        partner_id=current_user.partner_id,
        partner_name=partner_name,
        country=current_user.country,
        timezone=current_user.timezone,
        created_at=current_user.created_at,
        email_verified=current_user.email_verified_at is not None,
    )
