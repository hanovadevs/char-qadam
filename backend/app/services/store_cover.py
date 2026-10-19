"""Validate and normalize public brand covers before persistent storage."""
import io
import re
import uuid
import warnings
from pathlib import Path

from fastapi import HTTPException
from PIL import Image, ImageOps, UnidentifiedImageError

from app.config import Settings

MAX_COVER_BYTES = 4 * 1024 * 1024
MAX_COVER_PIXELS = 25_000_000


def cover_path(filename: str, settings: Settings) -> Path:
    if not re.fullmatch(r'[a-f0-9]{32}\.webp', filename):
        raise HTTPException(404, 'Cover not found')
    return Path(settings.media_directory).resolve() / 'store-covers' / filename


def save_cover(data: bytes, settings: Settings) -> tuple[str, Path]:
    if len(data) > MAX_COVER_BYTES:
        raise HTTPException(413, 'Choose a cover smaller than 4 MB')
    try:
        with warnings.catch_warnings():
            warnings.simplefilter('error', Image.DecompressionBombWarning)
            with Image.open(io.BytesIO(data)) as image:
                if image.format not in ('JPEG', 'PNG', 'WEBP'):
                    raise HTTPException(415, 'Use a JPEG, PNG or WebP cover')
                if image.width * image.height > MAX_COVER_PIXELS or getattr(image, 'n_frames', 1) != 1:
                    raise HTTPException(422, 'Use a still image with at most 25 megapixels')
                image.load()
                oriented = ImageOps.exif_transpose(image)
                normalized = ImageOps.fit(oriented, (1280, 720), method=Image.Resampling.LANCZOS)
                rgba = normalized.convert('RGBA')
                output = Image.new('RGB', rgba.size, 'white')
                output.paste(rgba, mask=rgba.getchannel('A'))
                encoded = io.BytesIO()
                # Re-encoding removes EXIF/GPS and other supplied metadata.
                output.save(encoded, format='WEBP', quality=82, method=4)
    except (UnidentifiedImageError, OSError, ValueError, Image.DecompressionBombError, Image.DecompressionBombWarning):
        raise HTTPException(422, 'This image could not be read. Choose a valid JPEG, PNG or WebP.') from None
    filename = f'{uuid.uuid4().hex}.webp'
    destination = cover_path(filename, settings)
    temporary = destination.with_suffix('.tmp')
    try:
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_bytes(encoded.getvalue())
        temporary.replace(destination)
    except OSError:
        try:
            temporary.unlink(missing_ok=True)
        except OSError:
            pass
        raise HTTPException(503, 'Cover storage is unavailable. Please try again later.') from None
    return f"{settings.public_api_url.rstrip('/')}/media/store-covers/{filename}", destination
