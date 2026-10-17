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
from app.services.security import decode_access_claims

_bearer = HTTPBearer(auto_error=False)

_401 = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Invalid or expired token",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_admin(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
) -> dict:
    if credentials is None:
        raise _401
    try:
        claims = decode_access_claims(credentials.credentials)
    except JWTError:
        raise _401
    if claims.get('role') != 'ADMIN' or claims['sub'] != 'admin_user_root':
        raise HTTPException(status_code=403, detail='Admin access required')
    return claims


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
        claims = decode_access_claims(credentials.credentials)
        user_id = claims['sub']
    except JWTError:
        raise _401

    result = await session.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise _401
    if claims.get('ver', 0) != user.auth_version:
        raise _401
    if user.email_verified_at is None:
        raise HTTPException(status_code=401, detail='Please sign in and verify your email.', headers={'WWW-Authenticate': 'Bearer'})
    if user.status != UserStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is suspended or deleted",
        )

    return user


_401_partner = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Authentication required: please log in as a merchant or provide a valid partner key",
    headers={"WWW-Authenticate": "Bearer"},
)


async def get_current_partner(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    x_partner_key: str | None = Header(default=None, alias="X-Partner-Key"),
    session: AsyncSession = Depends(get_session),
) -> Partner:
    """Validate Bearer JWT (for authenticated merchant users) OR ``X-Partner-Key`` header.

    Returns the Partner row. Raises HTTP 401 if unauthorized, or HTTP 403 if partner is INACTIVE.
    """
    # 1. Try Bearer JWT authentication (Primary login flow)
    if credentials is not None:
        try:
            claims = decode_access_claims(credentials.credentials)
            user_id = claims['sub']
            user_res = await session.execute(select(User).where(User.id == user_id))
            user = user_res.scalar_one_or_none()
            if user is not None and user.email_verified_at is not None and user.status == UserStatus.ACTIVE and user.partner_id and claims.get('ver', 0) == user.auth_version:
                partner = await session.get(Partner, user.partner_id)
                if partner is not None:
                    if partner.status != PartnerStatus.ACTIVE:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="Partner store account is inactive",
                        )
                    return partner
        except JWTError:
            pass  # Fall through to check X-Partner-Key if any

    # 2. Try legacy / machine-to-machine X-Partner-Key header
    if x_partner_key:
        key_hash = hash_api_key(x_partner_key)
        result = await session.execute(
            select(Partner).where(Partner.api_key_hash == key_hash)
        )
        partner = result.scalar_one_or_none()
        if partner is not None:
            if partner.status != PartnerStatus.ACTIVE:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Partner account is inactive",
                )
            return partner

    raise _401_partner
