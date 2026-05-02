"""Verify a TatbeeqX webhook signature.

Wire format (see docs/27-webhooks.md):
    X-Money-Signature: sha256=<hex of HMAC-SHA256(secret, raw-body-bytes)>

Always verify against the RAW request body bytes, never the JSON-parsed
dict (re-serialising can reorder keys or change whitespace, breaking the
HMAC).

Stdlib only — no third-party deps.

Importable as a module:

    from verify import verify
    ok = verify(raw_body, request.headers["X-Money-Signature"], SECRET)

Or runnable as a CLI for cross-language testing — reads the raw body from
stdin and exits 0 (valid) or 1 (invalid):

    SIG="sha256=..." SECRET="..." python verify.py
"""

import hmac
import hashlib
import os
import sys


def verify(raw_body, signature_header, secret):
    if not signature_header or not signature_header.startswith("sha256="):
        return False
    if isinstance(raw_body, str):
        raw_body = raw_body.encode("utf-8")
    if isinstance(secret, str):
        secret = secret.encode("utf-8")
    digest = hmac.new(secret, raw_body, hashlib.sha256).hexdigest()
    expected = "sha256=" + digest
    return hmac.compare_digest(expected, signature_header)


def _cli():
    raw = sys.stdin.buffer.read()
    sig = os.environ.get("SIG", "")
    secret = os.environ.get("SECRET", "")
    sys.exit(0 if verify(raw, sig, secret) else 1)


if __name__ == "__main__":
    _cli()
