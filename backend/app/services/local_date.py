"""Calendar-day boundaries follow the user's timezone, not the API host's clock."""
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def local_today(timezone_name: str | None = None, *, now: datetime | None = None):
    try:
        zone = ZoneInfo(timezone_name or 'Asia/Karachi')
    except ZoneInfoNotFoundError:
        zone = ZoneInfo('Asia/Karachi')
    return (now or datetime.now(timezone.utc)).astimezone(zone).date()
