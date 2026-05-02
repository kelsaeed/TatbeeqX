# Webhook signature verification helpers

Reference implementations for verifying TatbeeqX webhook signatures
in non-Node receivers. Pick the one that matches your stack — they all
implement the same wire format.

> Node receivers don't need this directory — the
> [`tools/backup-sync/receiver.js`](../backup-sync/receiver.js) shows the
> canonical Node verification, and the snippet in
> [docs/27-webhooks.md](../../docs/27-webhooks.md) is one line of
> `crypto.createHmac`.

## Wire format

Every TatbeeqX webhook delivery is a `POST` with:

```
Content-Type:        application/json
X-Money-Event:       <event-code>          e.g. "backup.created"
X-Money-Attempt:     <1..3>
X-Money-Signature:   sha256=<hex>
```

The signature is `HMAC-SHA256(secret, raw-body-bytes)` hex-encoded.

**Always verify against the raw body bytes**, not a re-serialised JSON
object. Most languages give you the raw body via a per-framework hook:

| Stack | Raw body |
|---|---|
| Express | `app.use(express.raw({ type: 'application/json' }))` then `req.body` |
| FastAPI / Starlette | `await request.body()` |
| Flask | `request.get_data()` |
| Go `net/http` | `io.ReadAll(r.Body)` |
| PHP | `file_get_contents('php://input')` |
| Rails | `request.raw_post` |

## Helpers in this directory

| Language | Files | Run tests |
|---|---|---|
| Python 3 | [`python/verify.py`](python/verify.py), [`python/test_verify.py`](python/test_verify.py) | `python test_verify.py` |
| Go | [`go/verify.go`](go/verify.go), [`go/verify_test.go`](go/verify_test.go) | `go test ./...` |
| PHP | [`php/verify.php`](php/verify.php), [`php/test_verify.php`](php/test_verify.php) | `php test_verify.php` |
| Bash + openssl | [`bash/verify.sh`](bash/verify.sh) | manual — see comments inside |

Every helper is **stdlib-only** — no package manager step required.

## Common interface

Each helper exposes a single function or callable that returns boolean:

```python
verify(raw_body, signature_header, secret) -> bool   # Python
```
```go
Verify(rawBody []byte, sigHeader, secret string) bool   // Go
```
```php
mc_verify_webhook($rawBody, $signatureHeader, $secret): bool   // PHP
```

The Bash helper is exit-code-driven: `cat body | SIG=... SECRET=... bash verify.sh && echo ok`.

All helpers use a constant-time compare (`hmac.compare_digest`,
`hmac.Equal`, `hash_equals`) — except the bash version, which uses a
plain string compare; see the note in [`bash/verify.sh`](bash/verify.sh).

## CLI mode (used by the cross-language test)

Each helper can also be invoked as a CLI for cross-language regression
testing:

```
echo -n "$RAW_BODY" | SIG="sha256=..." SECRET="..." python verify.py
echo -n "$RAW_BODY" | SIG="sha256=..." SECRET="..." go run verify.go
echo -n "$RAW_BODY" | SIG="sha256=..." SECRET="..." php verify.php
echo -n "$RAW_BODY" | SIG="sha256=..." SECRET="..." bash verify.sh
```

Each exits **0** if the signature is valid, **1** otherwise.

The Node test at
[`backend/tests/webhook_verify_helpers.test.js`](../../backend/tests/webhook_verify_helpers.test.js)
generates a known-good body+signature using the same code path the API
uses (`lib/webhooks.js`), then spawns each helper as a subprocess and
checks the exit code for both the good case and a tampered case. Helpers
whose toolchain isn't installed are skipped, so missing Go/PHP doesn't
break a Node-only dev box.

## Adding a new language

1. Create `tools/webhook-verify/<lang>/verify.<ext>` with the same
   common interface.
2. Add CLI mode that reads stdin / `SIG` env / `SECRET` env and exits 0
   or 1.
3. Write `test_verify.<ext>` exercising at least: valid, tampered body,
   wrong secret, missing prefix, empty header.
4. Add the language to the `LANGUAGES` array in
   [`backend/tests/webhook_verify_helpers.test.js`](../../backend/tests/webhook_verify_helpers.test.js)
   so the cross-test picks it up.
