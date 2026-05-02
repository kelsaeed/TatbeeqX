<?php
/**
 * Verify a TatbeeqX webhook signature.
 *
 * Wire format (see docs/27-webhooks.md):
 *   X-Money-Signature: sha256=<hex of HMAC-SHA256(secret, raw-body-bytes)>
 *
 * Always verify against the RAW request body bytes (file_get_contents('php://input')),
 * never the JSON-decoded array — re-serialising can reorder keys or
 * change whitespace, breaking the HMAC.
 *
 * Stdlib only — uses hash_hmac + hash_equals (PHP 5.6+).
 *
 * As a library, include this file and call mc_verify_webhook():
 *
 *   require __DIR__ . '/verify.php';
 *   $raw = file_get_contents('php://input');
 *   $sig = $_SERVER['HTTP_X_MONEY_SIGNATURE'] ?? '';
 *   if (!mc_verify_webhook($raw, $sig, $SECRET)) {
 *       http_response_code(401);
 *       exit('bad sig');
 *   }
 *
 * As a CLI for cross-language testing — reads the raw body from stdin
 * and exits 0 (valid) or 1 (invalid):
 *
 *   SIG="sha256=..." SECRET="..." php verify.php
 */

function mc_verify_webhook($rawBody, $signatureHeader, $secret) {
    if (!is_string($signatureHeader) || strpos($signatureHeader, 'sha256=') !== 0) {
        return false;
    }
    $digest = hash_hmac('sha256', (string)$rawBody, (string)$secret);
    $expected = 'sha256=' . $digest;
    return hash_equals($expected, $signatureHeader);
}

// CLI mode: invoked directly (not included by another script).
if (php_sapi_name() === 'cli'
    && isset($argv[0])
    && realpath($argv[0]) === __FILE__) {
    $raw = file_get_contents('php://stdin');
    $sig = getenv('SIG') ?: '';
    $secret = getenv('SECRET') ?: '';
    exit(mc_verify_webhook($raw, $sig, $secret) ? 0 : 1);
}
