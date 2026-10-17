"""Users router — profile management.

Routes
------
PATCH  /users/me   Update country, timezone, or password.
DELETE /users/me   Soft-delete the account (status → DELETED).

Soft-delete design
------------------
Setting status = DELETED is sufficient to invalidate all existing JWTs:
``get_current_user`` already rejects any user whose status != ACTIVE, so
there is no token blacklist to maintain for the MVP.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import User, UserStatus
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.auth import UserOut
from app.schemas.users import PatchUserIn
from app.services.security import hash_password, verify_password

router = APIRouter(prefix="/users", tags=["users"])


@router.patch(
    "/me",
    response_model=UserOut,
    summary="Update the authenticated user's profile",
)
async def patch_me(
    body: PatchUserIn,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> UserOut:
    """Partially update the authenticated user's profile.

    Only supplied (non-null) fields are written.  Password is re-hashed on
    change and the old hash is discarded.  Returns the updated profile.
    """
    updated = False

    if body.country is not None:
        current_user.country = body.country
        updated = True

    if body.timezone is not None:
        current_user.timezone = body.timezone
        updated = True

    if body.password is not None:
        current_user.password_hash = hash_password(body.password)
        current_user.auth_version += 1
        updated = True

    if updated:
        session.add(current_user)
        await session.commit()
        await session.refresh(current_user)

    return UserOut.model_validate(current_user)


@router.delete(
    "/me",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Soft-delete the authenticated user's account",
)
async def delete_me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    """Soft-delete the account by setting status to DELETED.

    All existing JWTs for this user are immediately invalidated because
    ``get_current_user`` rejects non-ACTIVE users.  No data is physically
    removed — a hard-delete job can run post-MVP.

    Returns **204 No Content** on success.
    """
    current_user.status = UserStatus.DELETED
    session.add(current_user)
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
