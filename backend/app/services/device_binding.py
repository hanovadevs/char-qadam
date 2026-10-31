"""Database-enforced device ownership; client identity is not hardware attestation."""
import re
from datetime import timedelta

from fastapi import Header, HTTPException
from sqlalchemy import func, select, or_
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


def device_slot(role: str) -> str:
    return 'merchant' if role == 'MERCHANT' else 'customer'


def slot_fields(role: str) -> tuple[str, str]:
    return ('merchant_user_id', 'merchant_generation') if role == 'MERCHANT' else ('user_id', 'generation')


def binding_generation(user: User, binding: DeviceBinding) -> int:
    return getattr(binding, slot_fields(user.role)[1])


async def check_device_available(key: str, user_id: str, session: AsyncSession, *, role: str = 'USER') -> None:
    binding = await session.get(DeviceBinding, key)
    owner = getattr(binding, slot_fields(role)[0]) if binding else None
    if owner and owner != user_id:
        owner_status = await session.scalar(select(User.status).where(User.id == owner))
        if owner_status is not None and owner_status != UserStatus.DELETED:
            raise HTTPException(409,
                'This phone is linked to another active merchant account. Sign in to that account or ask an administrator to deactivate it before using another merchant login.'
                if role == 'MERCHANT' else 'This phone is linked to another active account. Sign in to that account, '
                'or deactivate it from Profile before using a different account.')


async def claim_device(key: str, user: User, session: AsyncSession) -> DeviceBinding:
    # INSERT ... ON CONFLICT plus row locking also serializes the first claim.
    await session.execute(insert(DeviceBinding).values(id=key, generation=0).on_conflict_do_nothing(index_elements=['id']))
    binding = await session.scalar(select(DeviceBinding).where(DeviceBinding.id == key).with_for_update().execution_options(populate_existing=True))
    await check_device_available(key, user.id, session, role=user.role)
    owner_field, generation_field = slot_fields(user.role)
    if getattr(binding, owner_field) != user.id:
        setattr(binding, owner_field, user.id)
        setattr(binding, generation_field, getattr(binding, generation_field) + 1)
        if user.role == 'MERCHANT':
            return binding
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
    owner_field, generation_field = slot_fields(user.role)
    if (binding is None or getattr(binding, owner_field) != user.id
            or getattr(binding, generation_field) != claims.get('dgen')
            or claims.get('dslot', device_slot(user.role)) != device_slot(user.role)):
        raise HTTPException(401, 'Device access has changed. Please sign in again.')
    return key


async def release_devices(user: User, session: AsyncSession) -> None:
    bindings = (await session.execute(select(DeviceBinding).where(or_(DeviceBinding.user_id == user.id,
        DeviceBinding.merchant_user_id == user.id)).order_by(DeviceBinding.id).with_for_update())).scalars().all()
    for binding in bindings:
        for owner, generation in (slot_fields('USER'), slot_fields('MERCHANT')):
            if getattr(binding, owner) == user.id:
                setattr(binding, owner, None)
                setattr(binding, generation, getattr(binding, generation) + 1)
    # DeviceActivityDaily deliberately remains intact.


async def reclassify_devices(user: User, new_role: str, session: AsyncSession) -> None:
    """Role edits move only this identity's reservation; never displace another."""
    if device_slot(user.role) == device_slot(new_role):
        return
    old_owner, old_gen = slot_fields(user.role)
    new_owner, new_gen = slot_fields(new_role)
    bindings = (await session.scalars(select(DeviceBinding).where(getattr(DeviceBinding, old_owner) == user.id)
        .order_by(DeviceBinding.id).with_for_update())).all()
    for binding in bindings:
        await check_device_available(binding.id, user.id, session, role=new_role)
        setattr(binding, new_owner, user.id)
        setattr(binding, new_gen, getattr(binding, new_gen) + 1)
        setattr(binding, old_owner, None)
        setattr(binding, old_gen, getattr(binding, old_gen) + 1)
