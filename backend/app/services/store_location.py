"""Validate admin-supplied destinations before they reach mobile/external links."""
from urllib.parse import urlsplit


def normalize_maps_url(value: str | None) -> str | None:
    if value is None or not value.strip():
        return None
    value = value.strip()
    try:
        uri = urlsplit(value)
        host = (uri.hostname or '').lower()
        allowed = (
            host in {'maps.app.goo.gl', 'maps.google.com', 'maps.google.com.pk'}
            or (host == 'goo.gl' and uri.path.startswith('/maps'))
            or (host in {'google.com', 'www.google.com', 'google.com.pk', 'www.google.com.pk'}
                and (uri.path == '/maps' or uri.path.startswith('/maps/')))
        )
        if (len(value) <= 2048 and uri.scheme == 'https' and allowed
                and not uri.username and not uri.password and uri.port is None):
            return value
    except ValueError:
        pass
    raise ValueError('Use an HTTPS Google Maps place link or maps.app.goo.gl share link.')
