async def register_verified(client, *, json):
    """Exercise actual registration and the code delivered by the test mail transport."""
    registration = await client.post('/auth/register', json=json)
    assert registration.status_code == 201, registration.text
    assert 'access_token' not in registration.json()
    response = await client.post('/auth/verify-email', json={
        'verification_token': registration.json()['verification_token'],
        'code': client.verification_emails[json['email']],
    })
    assert response.status_code == 200, response.text
    return response
