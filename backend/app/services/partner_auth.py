"""Partner authentication utilities.

API key auth
------------
Partners authenticate via the ``X-Partner-Key`` HTTP header.  The raw key
is never stored — only ``SHA-256(key)`` is in the DB.  Comparison is done
by hashing the inbound key and looking up the hash.

Validate → Redeem nonce
-----------------------
The ``/validate`` endpoint returns a short-lived nonce that the POS must
submit to ``/redeem``.  This prevents:
  - Replay: nonce is time-bounded (``nonce_max_age_seconds`` in config).
  - Cross-partner misuse: the nonce embeds the issuing partner's id.
  - Direct redeem without validate: no nonce → no redeem.

Nonce format (opaque to clients):
    base64url( JSON_payload ) + "." + HMAC_hex_digest

Payload:
    {"vid": "<voucher_id>", "pid": "<partner_id>", "ts": <unix_seconds>}
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time


# ---------------------------------------------------------------------------
# API key helpers
# ---------------------------------------------------------------------------

def hash_api_key(raw_key: str) -> str:
    """Return the SHA-256 hex digest of *raw_key*.

    This is the value stored in ``partners.api_key_hash``.
    """
    return hashlib.sha256(raw_key.encode()).hexdigest()


# ---------------------------------------------------------------------------
# Nonce helpers
# ---------------------------------------------------------------------------

def _nonce_secret(settings) -> str:  # type: ignore[no-untyped-def]
    """Return the HMAC secret, falling back to jwt_secret when unset."""
    return settings.partner_nonce_secret or settings.jwt_secret


def generate_nonce(voucher_id: str, partner_id: str, settings) -> str:  # type: ignore[no-untyped-def]
    """Generate a signed nonce authorising *partner_id* to redeem *voucher_id*.

    Returns an opaque string safe to hand to the POS client.
    """
    payload = json.dumps(
        {"vid": voucher_id, "pid": partner_id, "ts": int(time.time())},
        separators=(",", ":"),
    )
    secret = _nonce_secret(settings)
    sig = hmac.new(secret.encode(), payload.encode(), hashlib.sha256).hexdigest()
    raw = f"{payload}.{sig}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def decode_nonce(nonce: str, settings) -> tuple[str, str]:  # type: ignore[no-untyped-def]
    """Decode and verify *nonce*.

    Returns ``(voucher_id, partner_id)`` on success.

    Raises ``ValueError`` with a human-readable message on any failure:
    - Invalid base64 / format
    - Bad HMAC signature (tampered)
    - Nonce older than ``nonce_max_age_seconds``
    """
    try:
        raw = base64.urlsafe_b64decode(nonce.encode()).decode()
        last_dot = raw.rfind(".")
        if last_dot == -1:
            raise ValueError("Malformed nonce")
        payload_str, sig = raw[:last_dot], raw[last_dot + 1:]
    except Exception:
        raise ValueError("Nonce could not be decoded")

    secret = _nonce_secret(settings)
    expected = hmac.new(secret.encode(), payload_str.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig, expected):
        raise ValueError("Nonce signature invalid")

    try:
        payload = json.loads(payload_str)
        voucher_id: str = payload["vid"]
        partner_id: str = payload["pid"]
        ts: int = payload["ts"]
    except (KeyError, TypeError, json.JSONDecodeError):
        raise ValueError("Nonce payload malformed")

    age = int(time.time()) - ts
    if age > settings.nonce_max_age_seconds:
        raise ValueError(f"Nonce expired ({age}s old, max {settings.nonce_max_age_seconds}s)")

    return voucher_id, partner_id
