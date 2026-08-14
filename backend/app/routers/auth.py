"""Auth router — registration, login, and current-user endpoints.

Routes
------
POST /auth/register   Create a new account; returns a JWT.
POST /auth/login      Authenticate with email+password; returns a JWT.
GET  /auth/me         Return the authenticated user's profile.
"""
from __future__ import annotations

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User, UserStatus
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.auth import LoginIn, RegisterIn, TokenOut, UserOut
from app.services.security import create_access_token, hash_password, verify_password

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

    return TokenOut(access_token=create_access_token(user.id))


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

    return TokenOut(access_token=create_access_token(user.id))


@router.get(
    "/me",
    response_model=UserOut,
    summary="Return the currently authenticated user",
)
async def me(current_user: User = Depends(get_current_user)) -> UserOut:
    """Return the profile of the bearer-token owner."""
    return UserOut.model_validate(current_user)
