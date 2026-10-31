import secrets
from app.services.security import decode_access_claims


def auth_headers(token):
    """Route each simulated user's session through the device that issued it."""
    claims = decode_access_claims(token)
    return {'Authorization': f'Bearer {token}', 'X-Device-ID': claims['did']}


async def device_token(client, user_id):
    from app.db.models import User
    from app.db.postgres import get_session_factory
    from app.services.device_binding import claim_device, binding_generation, device_slot
    from app.services.security import create_access_token
    async with get_session_factory()() as session:
        user = await session.get(User, user_id)
        binding = await claim_device(client.headers['X-Device-ID'], user, session)
        await session.commit()
        return create_access_token(user_id, extra_claims={'ver': user.auth_version, 'did': binding.id, 'dgen': binding_generation(user, binding), 'dslot': device_slot(user.role)})


async def register_verified(client, *, json):
    """Provision a distinct test phone, then complete actual mailbox verification."""
    client.headers['X-Device-ID'] = secrets.token_hex(32)
    registration = await client.post('/auth/register', json=json)
    assert registration.status_code == 201, registration.text
    assert 'access_token' not in registration.json()
    response = await client.post('/auth/verify-email', json={
        'verification_token': registration.json()['verification_token'],
        'code': client.verification_emails[json['email']],
    })
    assert response.status_code == 200, response.text
    return response
