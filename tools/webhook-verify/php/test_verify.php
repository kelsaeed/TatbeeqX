<?php
/**
 * Smoke tests for the PHP webhook verify helper.
 *
 * Run as:  php test_verify.php
 * Exits 0 on success, 1 on any failure.
 */

require __DIR__ . '/verify.php';

$SECRET = 'test-secret-do-not-use';
$BODY   = '{"event":"webhook.test","occurredAt":"2026-05-01T00:00:00.000Z","payload":{"hello":"world"}}';

function good_sig($secret, $body) {
    return 'sha256=' . hash_hmac('sha256', $body, $secret);
}

$cases = [
    // [label, body, sig, secret, expected]
    ['valid sig',         $BODY,         good_sig($SECRET, $BODY), $SECRET, true],
    ['tampered body',     $BODY . '!',   good_sig($SECRET, $BODY), $SECRET, false],
    ['wrong secret',      $BODY,         good_sig($SECRET, $BODY), 'different-secret', false],
    ['missing prefix',    $BODY,         substr(good_sig($SECRET, $BODY), 7), $SECRET, false],
    ['empty sig header',  $BODY,         '', $SECRET, false],
    ['empty body, valid', '',            good_sig($SECRET, ''), $SECRET, true],
];

$failures = [];
foreach ($cases as $c) {
    [$label, $body, $sig, $secret, $expected] = $c;
    $actual = mc_verify_webhook($body, $sig, $secret);
    if ($actual !== $expected) {
        $failures[] = sprintf('%s: expected %s, got %s', $label, var_export($expected, true), var_export($actual, true));
    }
}

if (count($failures) > 0) {
    foreach ($failures as $f) {
        fwrite(STDERR, "FAIL: $f\n");
    }
    exit(1);
}

echo 'ok (' . count($cases) . " cases)\n";
exit(0);
