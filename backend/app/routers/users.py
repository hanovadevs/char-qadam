from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import (User, UserStatus, ActivityDaily, Device, RedemptionRequest,
    SupportTicket, Voucher, VoucherStatus)
from app.db.postgres import get_session
from app.deps import get_current_user
from app.schemas.auth import UserOut
from app.schemas.users import PatchUserIn
from app.services.security import hash_password, verify_password
from app.services.device_binding import release_devices
from sqlalchemy import select, delete, update
from starlette.concurrency import run_in_threadpool
import secrets

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
    expected_version = current_user.auth_version
    current_user = await session.scalar(select(User).where(User.id == current_user.id)
        .with_for_update().execution_options(populate_existing=True))
    if current_user is None or current_user.status != UserStatus.ACTIVE or current_user.auth_version != expected_version:
        raise HTTPException(401, 'Please sign in again.')
    updated = False

    if body.country is not None:
        current_user.country = body.country
        updated = True

    if body.timezone is not None:
        current_user.timezone = body.timezone
        updated = True

    if body.password is not None:
        current_user.password_hash = await run_in_threadpool(hash_password, body.password)
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
    summary="Delete the authenticated user's account and personal data",
)
async def delete_me(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
) -> Response:
    """Erase profile, activity and support data in one transaction.

    Keep a non-login tombstone for existing accounting references. Device
    reward-consumption records remain unlinked from the deleted account to
    prevent earning the same physical steps repeatedly by re-registering.
    """
    current_user = await session.scalar(select(User).where(User.id == current_user.id).with_for_update().execution_options(populate_existing=True))
    if current_user is None or current_user.status != UserStatus.ACTIVE:
        raise HTTPException(401, "Please sign in again.")
    current_user.status = UserStatus.DELETED
    current_user.auth_version += 1
    await release_devices(current_user, session)
    # Retain de-identified AI cost counters so deletion cannot reset the shared budget.
    for model in (ActivityDaily, Device, RedemptionRequest, SupportTicket):
        await session.execute(delete(model).where(model.user_id == current_user.id))
    await session.execute(update(Voucher).where(
        Voucher.user_id == current_user.id, Voucher.status == VoucherStatus.ISSUED
    ).values(status=VoucherStatus.CANCELLED))
    current_user.email = f"deleted-{current_user.id}@deleted.invalid"
    current_user.password_hash = await run_in_threadpool(hash_password, secrets.token_urlsafe(48))
    current_user.google_subject = None
    current_user.email_verified_at = None
    current_user.verification_code_hash = None
    current_user.verification_expires_at = None
    current_user.verification_sent_at = None
    current_user.verification_attempts = 0
    current_user.country = None
    current_user.timezone = None
    current_user.partner_id = None
    session.add(current_user)
    await session.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
