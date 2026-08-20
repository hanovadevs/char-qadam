"""FastAPI dependencies shared across routers.

``get_current_user``
    Extracts and validates the Bearer JWT from the Authorization header,
    fetches the matching User row from the DB, and raises HTTP 401 on any
    failure.  Inject with ``Depends(get_current_user)``.
"""
from __future__ import annotations

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import Partner, PartnerStatus, User, UserStatus
from app.db.postgres import get_session
from app.services.partner_auth import hash_api_key
from app.services.security import decode_access_token

_bearer = HTTPBearer(auto_error=False)

_401 = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid or expired token",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: AsyncSession = Depends(get_session),
) -> User:
    """Validate Bearer JWT and return the authenticated User ORM object.

    Raises HTTP 401 if:
    - Authorization header is missing or not Bearer
    - Token is expired or has an invalid signature
    - The user_id in the token does not exist in the DB
    - The user account is not ACTIVE (suspended / deleted)
    """
    if credentials is None:
        raise _401

    try:
        user_id = decode_access_token(credentials.credentials)
    except JWTError:
        raise _401

    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise _401
    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is suspended or deleted",
        )

    return user


_401_partner = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid or missing partner API key",
    headers={"WWW-Authenticate": "X-Partner-Key"},
)


async def get_current_partner(
    x_partner_key: str | None = Header(default=None, alias="X-Partner-Key"),
    session: AsyncSession = Depends(get_session),
) -> Partner:
    """Validate the ``X-Partner-Key`` header and return the Partner row.

    Raises HTTP 401 if the header is missing or the key doesn't match any
    partner.  Raises HTTP 403 if the partner is INACTIVE.
    """
    if not x_partner_key:
        raise _401_partner

    key_hash = hash_api_key(x_partner_key)
    result = await session.execute(
        select(Partner).where(Partner.api_key_hash == key_hash)
    )
    partner = result.scalar_one_or_none()

    if partner is None:
        raise _401_partner
    if partner.status != PartnerStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Partner account is inactive",
        )

    return partner
