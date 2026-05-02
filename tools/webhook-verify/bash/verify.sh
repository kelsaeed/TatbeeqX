#!/usr/bin/env bash
# Verify a TatbeeqX webhook signature.
#
# Wire format (see docs/27-webhooks.md):
#   X-Money-Signature: sha256=<hex of HMAC-SHA256(secret, raw-body-bytes)>
#
# Reads the raw body from stdin. Reads SIG and SECRET from env. Exits 0
# (valid) or 1 (invalid). Prints nothing on success, a brief reason on
# failure (to stderr).
#
# Requires: bash, openssl. No third-party deps.
#
# Usage in a CGI / curl receive script:
#
#   curl -s ... | SIG="$X_MONEY_SIGNATURE" SECRET="$WEBHOOK_SECRET" \
#       bash verify.sh && process_event || exit 1
#
# Or in a simple while-true poller:
#
#   body=$(cat /tmp/last-body)
#   SIG="$header_value" SECRET="$secret" bash verify.sh <<< "$body"
#
# We use `openssl dgst -sha256 -hmac` for the HMAC and a literal-string
# compare for the result. This is NOT a constant-time compare — at the
# bash level we can't easily get one. The risk is a remote timing attack
# distinguishing valid signatures by response time. For the typical
# TatbeeqX receiver (a private LAN endpoint or a cloud function
# behind TLS) this is acceptable; if you're exposing the receiver to
# untrusted networks at high request rate, prefer the Go/Python/PHP
# helper which use language-native constant-time compares.

set -euo pipefail

if [[ -z "${SIG:-}" ]]; then
  echo "verify.sh: SIG env var is required" >&2
  exit 1
fi
if [[ -z "${SECRET:-}" ]]; then
  echo "verify.sh: SECRET env var is required" >&2
  exit 1
fi

# Strip the "sha256=" prefix; bail out if missing.
if [[ "$SIG" != sha256=* ]]; then
  echo "verify.sh: signature missing 'sha256=' prefix" >&2
  exit 1
fi
provided_hex="${SIG#sha256=}"

# Compute HMAC. `openssl dgst` prints `(stdin)= <hex>`; we strip the
# prefix with awk. -binary would emit raw bytes; -hex is the default.
expected_hex="$(openssl dgst -sha256 -hmac "$SECRET" | awk '{print $NF}')"

if [[ "$expected_hex" == "$provided_hex" ]]; then
  exit 0
fi
exit 1
