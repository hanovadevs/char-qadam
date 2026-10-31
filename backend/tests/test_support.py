from datetime import datetime, timedelta, timezone
from types import SimpleNamespace
import uuid
import pytest
from fastapi import HTTPException
from sqlalchemy import select, delete
from app.db.models import SupportAISettings, SupportAIUsage
from app.db.postgres import get_session_factory
from app.services.support import reserve_ai_allowance, RESERVED_TOKENS


async def account(client):
    from tests.auth_helpers import register_verified, auth_headers
    response = await register_verified(client, json={'email': f'support-{uuid.uuid4().hex}@example.com', 'password': 'test-password-123'})
    return auth_headers(response.json()['access_token'])


@pytest.fixture
def admin_headers():
    from app.services.security import create_access_token
    return {'Authorization': 'Bearer ' + create_access_token(subject='admin_user_root', extra_claims={'role': 'ADMIN'})}


@pytest.mark.asyncio
async def test_tickets_are_private_and_admin_can_reply(client, admin_headers):
    owner = await account(client)
    other = await account(client)
    response = await client.post('/support/tickets', headers=owner, json={'subject': 'Missing step sync', 'message': 'My steps have not updated today', 'category': 'steps'})
    assert response.status_code == 201
    ticket = response.json()['id']
    listing = await client.get('/admin/support/tickets', headers=admin_headers)
    assert listing.status_code == 200, listing.text
    listed_ticket = next(row for row in listing.json() if row['id'] == ticket)
    assert listed_ticket['user_email'].startswith('support-')
    assert (await client.get(f'/support/tickets/{ticket}', headers=other)).status_code == 404
    assert (await client.post(f'/support/tickets/{ticket}/messages', headers=other, json={'message': 'Not my ticket'})).status_code == 404
    assert (await client.get('/admin/support/tickets', headers=owner)).status_code == 403
    reply = await client.post(f'/admin/support/tickets/{ticket}/messages', headers=admin_headers, json={'message': 'Please check your activity permission.'})
    assert reply.status_code == 200
    assert reply.json()['status'] == 'WAITING'
    own = await client.get(f'/support/tickets/{ticket}', headers=owner)
    assert len(own.json()['messages']) == 2
    assert own.json()['messages'][1]['author'] == 'ADMIN'


@pytest.mark.asyncio
async def test_faq_and_off_topic_questions_never_call_openai(client):
    headers = await account(client)
    faqs = (await client.get('/support/faqs', headers=headers)).json()['faqs']
    local = await client.post('/support/chat', headers=headers, json={'message': faqs[0]['question'], 'consent': True})
    assert local.status_code == 200 and local.json()['source'] == 'faq'
    off_topic = await client.post('/support/chat', headers=headers, json={'message': 'Write a poem about a mountain', 'consent': True})
    assert off_topic.status_code == 200 and off_topic.json()['source'] == 'local'
    assert (await client.post('/support/chat', headers=headers, json={'message': 'help with steps', 'consent': False})).status_code == 422


@pytest.mark.asyncio
async def test_ai_quotas_are_shared_atomic_and_cannot_be_reset_by_restarting_client():
    factory = get_session_factory()
    # This suite is restricted to a disposable loopback database by conftest.
    async with factory() as session:
        await session.execute(delete(SupportAIUsage))
        await session.execute(delete(SupportAISettings))
        await session.commit()
    user = str(uuid.uuid4())
    day = datetime.now(timezone.utc).date().isoformat()
    async with factory() as session:
        session.add(SupportAISettings(id='global', enabled=True, user_daily_limit=1, global_daily_limit=2, daily_token_budget=20000))
        await session.commit()
    async with factory() as first:
        returned_day, remaining = await reserve_ai_allowance(first, user)
        assert returned_day == day and remaining == 0
    async with factory() as second:
        with pytest.raises(HTTPException) as limited:
            await reserve_ai_allowance(second, user)
        assert limited.value.status_code == 429
    # A different user consumes the final shared slot; a third is blocked.
    async with factory() as second_user:
        await reserve_ai_allowance(second_user, str(uuid.uuid4()))
    async with factory() as third:
        with pytest.raises(HTTPException) as limited:
            await reserve_ai_allowance(third, str(uuid.uuid4()))
        assert limited.value.status_code == 429
    async with factory() as session:
        usage = (await session.execute(select(SupportAIUsage).where(SupportAIUsage.user_id == user, SupportAIUsage.day == day))).scalar_one()
        assert usage.requests == 1 and usage.charged_tokens == RESERVED_TOKENS


@pytest.mark.asyncio
async def test_admin_cannot_enable_ai_without_a_server_key(client, admin_headers, monkeypatch):
    from app.config import get_settings
    monkeypatch.setenv('OPENAI_API_KEY', '')
    get_settings.cache_clear()
    response = await client.patch('/admin/support/ai', headers=admin_headers, json={'enabled': True})
    assert response.status_code == 409
