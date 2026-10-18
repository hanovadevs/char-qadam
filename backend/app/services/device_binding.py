"""Database-enforced device ownership; client identity is not hardware attestation."""
import re
from datetime import timedelta

from fastapi import Header, HTTPException
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.models import ActivityDaily, DeviceActivityDaily, DeviceBinding, User, UserStatus
from app.services.local_date import local_today


def device_key(value: str | None) -> str:
    if value is None:
        raise HTTPException(426, 'Please update Stepsy to use device-protected sign-in.')
    if not re.fullmatch(r'[a-fA-F0-9]{64}', value):
        raise HTTPException(400, 'Invalid device identity. Please restart Stepsy.')
    return value.lower()


async def require_device_key(x_device_id: str | None = Header(default=None, alias='X-Device-ID')) -> str:
    return device_key(x_device_id)


async def check_device_available(key: str, user_id: str, session: AsyncSession) -> None:
    binding = await session.get(DeviceBinding, key)
    if binding and binding.user_id and binding.user_id != user_id:
        owner_status = await session.scalar(select(User.status).where(User.id == binding.user_id))
        if owner_status is not None and owner_status != UserStatus.DELETED:
            raise HTTPException(409,
                'This phone is linked to another active account. Sign in to that account, '
                'or deactivate it from Profile before using a different account.')


async def claim_device(key: str, user: User, session: AsyncSession) -> DeviceBinding:
    # INSERT ... ON CONFLICT plus row locking also serializes the first claim.
    await session.execute(insert(DeviceBinding).values(id=key, generation=0).on_conflict_do_nothing(index_elements=['id']))
    binding = await session.scalar(select(DeviceBinding).where(DeviceBinding.id == key).with_for_update().execution_options(populate_existing=True))
    await check_device_available(key, user.id, session)
    if binding.user_id != user.id:
        binding.user_id = user.id
        binding.generation += 1
        # Preserve credits earned by a legacy account before device binding existed.
        # This consumes history; it never grants points or guesses old ownership.
        today = local_today(user.timezone)
        days = (await session.execute(select(ActivityDaily.local_date, ActivityDaily.eligible_steps).where(
            ActivityDaily.user_id == user.id,
            ActivityDaily.local_date >= (today - timedelta(days=7)).isoformat(),
            ActivityDaily.local_date <= today.isoformat()))).all()
        for date, steps in days:
            statement = insert(DeviceActivityDaily).values(device_id=key, local_date=date, eligible_steps=steps)
            await session.execute(statement.on_conflict_do_update(
                index_elements=['device_id', 'local_date'],
                set_={'eligible_steps': func.greatest(DeviceActivityDaily.eligible_steps, steps)}))
    return binding


async def validate_device(key: str | None, user: User, claims: dict, session: AsyncSession) -> str:
    key = device_key(key)
    if claims.get('did') != key:
        raise HTTPException(401, 'Please sign in again on this phone.')
    binding = await session.get(DeviceBinding, key)
    return validate_binding(key, user, claims, binding)


def validate_binding(key: str | None, user: User, claims: dict, binding: DeviceBinding | None) -> str:
    key = device_key(key)
    if claims.get('did') != key:
        raise HTTPException(401, 'Please sign in again on this phone.')
    if binding is None or binding.user_id != user.id or binding.generation != claims.get('dgen'):
        raise HTTPException(401, 'Device access has changed. Please sign in again.')
    return key


async def release_devices(user: User, session: AsyncSession) -> None:
    bindings = (await session.execute(select(DeviceBinding).where(DeviceBinding.user_id == user.id).order_by(DeviceBinding.id).with_for_update())).scalars().all()
    for binding in bindings:
        binding.user_id = None
        binding.generation += 1
    # DeviceActivityDaily deliberately remains intact.
