"""Admin location edits reach the catalog; unsafe destinations are rejected."""
import uuid

import pytest
from pydantic import ValidationError

from app.routers.admin import AdminPartnerPatchIn
from app.services.store_location import normalize_maps_url
from tests.auth_helpers import auth_headers, register_verified


@pytest.mark.parametrize('url', [
    'https://maps.app.goo.gl/Branch123',
    'https://www.google.com/maps/place/Lahore/',
    'https://google.com/maps/search/?api=1&query=Lahore',
    'https://maps.google.com/?q=Lahore',
    'https://www.google.com.pk/maps/place/Karachi',
    'https://goo.gl/maps/Branch123',
])
def test_google_maps_links_are_accepted(url):
    assert normalize_maps_url(f' {url} ') == url


@pytest.mark.parametrize('url', [
    'javascript:alert(1)', 'intent://maps', 'http://maps.google.com/?q=Lahore',
    'https://google.com.evil.example/maps', 'https://evil.example/maps',
    'https://www.google.com/search?q=store', 'https://goo.gl/something',
    'https://attacker@maps.google.com/maps', 'https://maps.google.com:443/maps',
    'https://maps.app.goo.gl:bad/maps', 'https://maps.app.goo.gl/' + 'a' * 2049,
])
def test_unsafe_or_non_maps_links_are_rejected(url):
    with pytest.raises(ValidationError):
        AdminPartnerPatchIn(google_maps_url=url)


def test_clear_and_omit_location_are_distinct():
    assert AdminPartnerPatchIn(google_maps_url='  ').google_maps_url is None
    assert 'google_maps_url' in AdminPartnerPatchIn(google_maps_url='').model_fields_set
    assert 'google_maps_url' not in AdminPartnerPatchIn(name='Cafe').model_fields_set


@pytest.mark.asyncio
async def test_admin_location_edits_and_removal_reach_customer_catalog(admin_client):
    created = await admin_client.post('/admin/partners', json={
        'name': 'Location test cafe', 'email': f'maps_{uuid.uuid4().hex}@example.com',
        'password': 'location-test-only-123', 'location': 'Gulberg, Lahore',
        'google_maps_url': 'https://maps.app.goo.gl/FirstBranch',
    })
    assert created.status_code == 201, created.text
    partner = created.json()['id']
    offer = await admin_client.post('/admin/offers', json={
        'partner_id': partner, 'title': 'Location test reward', 'discount_type': 'PERCENT',
        'discount_value': 10, 'points_cost': 100,
    })
    assert offer.status_code == 201, offer.text
    offer_id = offer.json()['id']
    user = await register_verified(admin_client, json={
        'email': f'maps_customer_{uuid.uuid4().hex}@example.com', 'password': 'location-test-only-123',
    })
    assert user.status_code == 200, user.text
    headers = auth_headers(user.json()['access_token'])

    async def catalog():
        response = await admin_client.get('/offers', headers=headers)
        assert response.status_code == 200, response.text
        return next(o for o in response.json() if o['id'] == offer_id)

    assert (await catalog())['partner_google_maps_url'] == 'https://maps.app.goo.gl/FirstBranch'
    updated = await admin_client.patch(f'/admin/partners/{partner}', json={
        'google_maps_url': 'https://www.google.com/maps/place/SecondBranch', 'location': 'Clifton, Karachi',
    })
    assert updated.status_code == 200, updated.text
    item = await catalog()
    assert item['partner_location'] == 'Clifton, Karachi'
    assert item['partner_google_maps_url'] == 'https://www.google.com/maps/place/SecondBranch'
    assert (await admin_client.patch(f'/admin/partners/{partner}', json={'name': 'Renamed cafe'})).status_code == 200
    assert (await catalog())['partner_google_maps_url'].endswith('SecondBranch')
    assert (await admin_client.patch(f'/admin/partners/{partner}', json={'google_maps_url': ''})).status_code == 200
    assert (await catalog())['partner_google_maps_url'] is None
    invalid = await admin_client.patch(f'/admin/partners/{partner}', json={'google_maps_url': 'https://evil.example/maps'})
    assert invalid.status_code == 422
    assert (await catalog())['partner_google_maps_url'] is None
