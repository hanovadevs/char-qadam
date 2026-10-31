"""Password recovery delivery; credentials never appear in responses or logs."""
from email.message import EmailMessage
import smtplib
import ssl

from app.config import Settings


def send_password_reset_email(email: str, token: str, settings: Settings) -> None:
    message = EmailMessage()
    message['Subject'] = 'Reset your Stepsy password'
    message['From'] = settings.smtp_from
    message['To'] = email
    message.set_content(
        'You requested a Stepsy password reset. Paste this reset token into '
        'the app to choose a new password. It expires in 15 minutes and can '
        f'only be used once.\n\n{token}\n\n'
        'If you did not request this, ignore this email.'
    )
    _send(message, settings)


def send_verification_email(email: str, code: str, settings: Settings) -> None:
    message = EmailMessage()
    message['Subject'] = 'Verify your Stepsy email'
    message['From'] = settings.smtp_from
    message['To'] = email
    message.set_content(
        f'Your Stepsy verification code is: {code}\n\n'
        'Enter it in the app to verify your email. The code expires in 10 minutes '
        'and can only be used once. Never share this code.\n\n'
        'If you did not request this, ignore this email.'
    )
    _send(message, settings)


def _send(message: EmailMessage, settings: Settings) -> None:
    context = ssl.create_default_context()
    if settings.smtp_use_ssl:
        server = smtplib.SMTP_SSL(settings.smtp_host, settings.smtp_port, timeout=15, context=context)
    else:
        server = smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15)
    with server:
        if not settings.smtp_use_ssl:
            server.starttls(context=context)
        if settings.smtp_username:
            server.login(settings.smtp_username, settings.smtp_password)
        server.send_message(message)
