"""Smoke tests for the Python webhook verify helper.

Run as:  python test_verify.py
Exits 0 on success, 1 on any failure.
"""

import hmac
import hashlib
import sys

from verify import verify


SECRET = "test-secret-do-not-use"
BODY = (
    b'{"event":"webhook.test","occurredAt":"2026-05-01T00:00:00.000Z",'
    b'"payload":{"hello":"world"}}'
)


def good_sig(secret=SECRET, body=BODY):
    return "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def main():
    failures = []

    cases = [
        # (label, raw_body, sig_header, secret, expected_result)
        ("valid sig", BODY, good_sig(), SECRET, True),
        ("tampered body", BODY + b"!", good_sig(), SECRET, False),
        ("wrong secret", BODY, good_sig(), "different-secret", False),
        ("missing prefix", BODY, good_sig().replace("sha256=", ""), SECRET, False),
        ("empty sig header", BODY, "", SECRET, False),
        ("bytes secret", BODY, good_sig(), SECRET.encode(), True),
        ("str body", BODY.decode(), good_sig(), SECRET, True),
    ]

    for label, body, sig, secret, expected in cases:
        actual = verify(body, sig, secret)
        if actual != expected:
            failures.append(f"{label}: expected {expected}, got {actual}")

    if failures:
        for f in failures:
            print("FAIL:", f)
        sys.exit(1)
    print(f"ok ({len(cases)} cases)")


if __name__ == "__main__":
    main()
