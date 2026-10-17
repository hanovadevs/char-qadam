"""Auth router — registration, login, password recovery, and current-user endpoints.

Routes
------
POST /auth/register         Create a new account; returns a JWT.
POST /auth/login            Authenticate with email+password; returns a JWT.
POST /auth/google           Authenticate via Google OAuth ID Token; returns a JWT.
POST /auth/forgot-password  Request a signed password reset token.
POST /auth/reset-password   Reset password with valid reset token.
GET  /auth/me               Return the authenticated user's profile.
"""
from __future__ import annotations

import asyncio
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
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
)
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


@router.post(
    "/register",
    response_model=TokenOut,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user account",
)
async def register(
    body: RegisterIn,
    session: AsyncSession = Depends(get_session),
) -> TokenOut:
    """Create a new user and return a JWT.

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
    session.add(user)
    await session.commit()

    return TokenOut(
        access_token=create_access_token(user.id, extra_claims={"role": user.role}),
        role=user.role,
    )


@router.post(
    "/login",
    response_model=TokenOut,
    summary="Log in and receive a JWT",
)
async def login(
    body: LoginIn,
    session: AsyncSession = Depends(get_session),
) -> TokenOut:
    """Authenticate with email + password.

    Returns **401** on invalid credentials (deliberately vague to prevent
    email enumeration).
    """
    result = await session.execute(
        select(User).where(User.email == body.email)
    )
    user = result.scalar_one_or_none()

    if user is None or not verify_password(body.password, user.password_hash):
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

    partner_name = None
    if user.partner_id:
        partner = await session.get(Partner, user.partner_id)
        if partner:
            partner_name = partner.name

    token = create_access_token(
        user.id,
        extra_claims={
            "role": user.role,
            "partner_id": user.partner_id,
        },
    )
    return TokenOut(
        access_token=token,
        role=user.role,
        partner_id=user.partner_id,
        partner_name=partner_name,
    )


@router.post(
    "/google",
    response_model=TokenOut,
    summary="Authenticate via Google OAuth ID Token",
)
async def google_auth(
    body: GoogleAuthIn,
    session: AsyncSession = Depends(get_session),
) -> TokenOut:
    """Exchange a Google OAuth ID Token for a Qadam JWT.

    If the user does not exist in the system, a new account is automatically
    created. If the account exists, it is logged in.

    Returns **401** if the Google token is invalid or unverified.
    """
    settings = get_settings()
    try:
        verified_info = await verify_google_id_token(
            body.id_token,
            client_id=settings.google_client_id if settings.google_client_id else None,
        )
        email = verified_info.get("email")
    except Exception:
        email = None

    if not email:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or unverified Google ID Token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Check if user already exists
    result = await session.execute(
        select(User).where(User.email == email)
    )
    user = result.scalar_one_or_none()

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
        await session.commit()
    else:
        if user.status != UserStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Account is suspended or deleted",
            )

    partner_name = None
    if user.partner_id:
        partner = await session.get(Partner, user.partner_id)
        if partner:
            partner_name = partner.name

    return TokenOut(
        access_token=create_access_token(user.id, extra_claims={"role": user.role, "partner_id": user.partner_id}),
        role=user.role,
        partner_id=user.partner_id,
        partner_name=partner_name,
    )


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
        reset_token = create_password_reset_token(user.id, user.password_hash)
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
        decode_password_reset_token(body.reset_token, user.password_hash)
    except Exception:
        raise HTTPException(status_code=400, detail='Invalid or expired password reset token')
    user.password_hash = hash_password(body.new_password)
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
    )
