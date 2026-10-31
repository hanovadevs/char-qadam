import pytest


@pytest.mark.asyncio
@pytest.mark.parametrize('path', ['/privacy', '/privacy.html', '/delete-account', '/delete-account.html'])
async def test_public_review_pages_need_no_login(client, path):
    response = await client.get(path)
    assert response.status_code == 200
    assert response.headers['content-type'].startswith('text/html')
    assert 'Stepsy' in response.text and 'Hanova Devs' in response.text
    assert 'contact@hanovadevs.com' in response.text
    assert 'Delete account' in response.text
