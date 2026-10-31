"""Authenticated support tickets and opt-in AI help; no privileged model actions."""
from datetime import datetime, timedelta, timezone
from typing import Literal
import httpx
from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, Field, field_validator
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from app.config import get_settings
from app.db.models import AuditLog, SupportAISettings, SupportAIUsage, SupportMessage, SupportTicket, User, UserStatus
from app.db.postgres import get_session
from app.deps import get_current_user, get_current_admin
from app.services.support import faqs, support_question_allowed, reserve_ai_allowance, ask_ai, RESERVED_TOKENS

router = APIRouter(prefix='/support', tags=['support'])
admin_router = APIRouter(prefix='/admin/support', tags=['support-admin'], dependencies=[Depends(get_current_admin)])
Category = Literal['steps', 'points', 'vouchers', 'account', 'technical']

class MessageIn(BaseModel):
    message: str = Field(min_length=5, max_length=2000)
    @field_validator('message')
    @classmethod
    def meaningful(cls, value):
        if len(value.strip()) < 5:
            raise ValueError('Please describe the issue')
        return value.strip()

class TicketIn(MessageIn):
    subject: str = Field(min_length=5, max_length=120)
    category: Category

class ChatIn(BaseModel):
    message: str = Field(min_length=5, max_length=600)
    consent: Literal[True]

class StatusIn(BaseModel):
    status: Literal['OPEN', 'WAITING', 'RESOLVED']

class AISettingsIn(BaseModel):
    enabled: bool
    user_daily_limit: int = Field(default=5, ge=1, le=20)
    global_daily_limit: int = Field(default=300, ge=1, le=1000)
    daily_token_budget: int = Field(default=200000, ge=8192, le=1000000)

@router.get('/faqs')
async def get_faqs(user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    settings = get_settings()
    config = await session.get(SupportAISettings, 'global')
    return {'faqs': faqs(), 'ai_available': bool(settings.openai_api_key and config and config.enabled)}

@router.post('/chat')
async def chat(body: ChatIn, request: Request, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    # Exact FAQ questions are always answered locally, without quota or API use.
    for faq in faqs():
        if body.message.strip().casefold() == faq['question'].casefold():
            return {'answer': faq['answer'], 'source': 'faq', 'remaining': None}
    if not support_question_allowed(body.message):
        return {'answer': 'I can help with Stepsy steps, points, vouchers, and account use. Please choose a FAQ or open a support ticket for another app issue.', 'source': 'local', 'remaining': None}
    if not get_settings().openai_api_key:
        raise HTTPException(status_code=503, detail='AI help is unavailable. FAQs and support tickets are available.')
    day, remaining = await reserve_ai_allowance(session, user.id)
    client = getattr(request.app.state, 'support_ai_client', None)
    if client is None:
        raise HTTPException(status_code=503, detail='AI help is temporarily unavailable')
    answer, input_tokens, output_tokens = await ask_ai(body.message.strip(), client)
    # Failed calls retain the reservation, bounding cost even on ambiguous errors.
    await session.execute(update(SupportAIUsage).where(SupportAIUsage.user_id == user.id, SupportAIUsage.day == day).values(
        charged_tokens=SupportAIUsage.charged_tokens - RESERVED_TOKENS + max(1, input_tokens + output_tokens),
        input_tokens=SupportAIUsage.input_tokens + input_tokens,
        output_tokens=SupportAIUsage.output_tokens + output_tokens,
    ))
    await session.commit()
    return {'answer': answer, 'source': 'ai', 'remaining': remaining}


def ticket_data(ticket):
    return {key: getattr(ticket, key) for key in ['id', 'subject', 'category', 'status', 'created_at', 'updated_at']}

async def get_ticket(session, ticket_id, user_id=None, lock=False):
    query = select(SupportTicket).where(SupportTicket.id == ticket_id)
    if user_id is not None:
        query = query.where(SupportTicket.user_id == user_id)
    if lock:
        query = query.with_for_update()
    ticket = (await session.execute(query)).scalar_one_or_none()
    if ticket is None:
        raise HTTPException(status_code=404, detail='Support ticket not found')
    return ticket

async def detail(session, ticket):
    rows = (await session.execute(select(SupportMessage).where(SupportMessage.ticket_id == ticket.id).order_by(SupportMessage.created_at, SupportMessage.id).limit(100))).scalars().all()
    return {**ticket_data(ticket), 'messages': [{'id': m.id, 'author': m.author, 'message': m.body, 'created_at': m.created_at} for m in rows]}

@router.post('/tickets', status_code=201)
async def create_ticket(body: TicketIn, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    active = await session.scalar(select(User.id).where(
        User.id == user.id, User.status == UserStatus.ACTIVE,
        User.auth_version == user.auth_version).with_for_update())
    if active is None:
        raise HTTPException(401, 'Please sign in again.')
    start = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    count = (await session.execute(select(func.count()).select_from(SupportTicket).where(SupportTicket.user_id == user.id, SupportTicket.created_at >= start))).scalar_one()
    if count >= 5:
        raise HTTPException(status_code=429, detail='You can open up to five tickets per day. Reply to an existing ticket instead.')
    ticket = SupportTicket(user_id=user.id, subject=body.subject.strip(), category=body.category)
    session.add(ticket)
    await session.flush()
    session.add(SupportMessage(ticket_id=ticket.id, author='USER', body=body.message))
    await session.commit()
    return ticket_data(ticket)

@router.get('/tickets')
async def list_tickets(limit: int = Query(50, ge=1, le=100), offset: int = Query(0, ge=0), user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    rows = (await session.execute(select(SupportTicket).where(SupportTicket.user_id == user.id).order_by(SupportTicket.updated_at.desc(), SupportTicket.id).limit(limit).offset(offset))).scalars().all()
    return [ticket_data(row) for row in rows]

@router.get('/tickets/{ticket_id}')
async def ticket_detail(ticket_id: str, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    return await detail(session, await get_ticket(session, ticket_id, user.id))

async def add_reply(session, ticket, message, author):
    count = (await session.execute(select(func.count()).select_from(SupportMessage).where(SupportMessage.ticket_id == ticket.id))).scalar_one()
    if count >= 100:
        raise HTTPException(status_code=409, detail='This conversation is full. Please open a new ticket.')
    if author == 'USER' and (datetime.now(timezone.utc) - ticket.updated_at).total_seconds() < 5:
        raise HTTPException(status_code=429, detail='Please wait a few seconds before sending another message')
    session.add(SupportMessage(ticket_id=ticket.id, author=author, body=message))
    ticket.updated_at = datetime.now(timezone.utc)
    ticket.status = 'WAITING' if author == 'ADMIN' else 'OPEN'
    if author == 'ADMIN':
        session.add(AuditLog(actor='admin', action='REPLY_SUPPORT_TICKET', object_type='SUPPORT_TICKET', object_id=ticket.id))
    await session.commit()
    return await detail(session, ticket)

@router.post('/tickets/{ticket_id}/messages')
async def reply(ticket_id: str, body: MessageIn, user: User = Depends(get_current_user), session: AsyncSession = Depends(get_session)):
    return await add_reply(session, await get_ticket(session, ticket_id, user.id, lock=True), body.message, 'USER')

@admin_router.get('/tickets')
async def admin_tickets(status: Literal['ALL', 'OPEN', 'WAITING', 'RESOLVED'] = 'ALL', limit: int = Query(51, ge=1, le=100), offset: int = Query(0, ge=0), session: AsyncSession = Depends(get_session)):
    query = select(SupportTicket, User, UserStatus.email).join(User, User.id == SupportTicket.user_id)
    if status != 'ALL':
        query = query.where(SupportTicket.status == status)
    rows = (await session.execute(query.order_by(SupportTicket.updated_at.desc(), SupportTicket.id).limit(limit).offset(offset))).all()
    return [{**ticket_data(ticket), 'user_email': email} for ticket, email in rows]

@admin_router.get('/tickets/{ticket_id}')
async def admin_detail(ticket_id: str, session: AsyncSession = Depends(get_session)):
    return await detail(session, await get_ticket(session, ticket_id))

@admin_router.post('/tickets/{ticket_id}/messages')
async def admin_reply(ticket_id: str, body: MessageIn, session: AsyncSession = Depends(get_session)):
    return await add_reply(session, await get_ticket(session, ticket_id, lock=True), body.message, 'ADMIN')

@admin_router.patch('/tickets/{ticket_id}')
async def admin_status(ticket_id: str, body: StatusIn, session: AsyncSession = Depends(get_session)):
    ticket = await get_ticket(session, ticket_id, lock=True)
    ticket.status = body.status
    ticket.updated_at = datetime.now(timezone.utc)
    session.add(AuditLog(actor='admin', action=f'SUPPORT_{body.status}', object_type='SUPPORT_TICKET', object_id=ticket.id))
    await session.commit()
    return ticket_data(ticket)

@admin_router.get('/ai')
async def ai_status(session: AsyncSession = Depends(get_session)):
    config = await session.get(SupportAISettings, 'global')
    day = datetime.now(timezone.utc).date().isoformat()
    requests, charged, inputs, outputs = (await session.execute(select(
        func.coalesce(func.sum(SupportAIUsage.requests), 0), func.coalesce(func.sum(SupportAIUsage.charged_tokens), 0),
        func.coalesce(func.sum(SupportAIUsage.input_tokens), 0), func.coalesce(func.sum(SupportAIUsage.output_tokens), 0),
    ).where(SupportAIUsage.day == day))).one()
    return {'configured': bool(get_settings().openai_api_key), 'enabled': config.enabled if config else False,
            'model': get_settings().openai_support_model, 'user_daily_limit': config.user_daily_limit if config else 5,
            'global_daily_limit': config.global_daily_limit if config else 300, 'daily_token_budget': config.daily_token_budget if config else 200000,
            'today': {'day': day, 'requests': requests, 'charged_tokens': charged, 'input_tokens': inputs, 'output_tokens': outputs}}

@admin_router.patch('/ai')
async def configure_ai(body: AISettingsIn, session: AsyncSession = Depends(get_session)):
    await session.execute(select(func.pg_advisory_xact_lock(762647497)))
    if body.enabled and not get_settings().openai_api_key:
        raise HTTPException(status_code=409, detail='Configure OPENAI_API_KEY on the server before enabling AI')
    config = await session.get(SupportAISettings, 'global')
    if config is None:
        config = SupportAISettings(id='global')
        session.add(config)
    for key, value in body.model_dump().items():
        setattr(config, key, value)
    session.add(AuditLog(actor='admin', action='CONFIGURE_SUPPORT_AI', object_type='SYSTEM'))
    await session.commit()
    return await ai_status(session)
