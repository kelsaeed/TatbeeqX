// Verify a TatbeeqX webhook signature.
//
// Wire format (see docs/27-webhooks.md):
//
//	X-Money-Signature: sha256=<hex of HMAC-SHA256(secret, raw-body-bytes)>
//
// Always verify against the raw request body bytes, never the JSON-parsed
// struct (re-serialising can reorder keys or change whitespace, breaking
// the HMAC).
//
// Stdlib only — no third-party deps.
//
// As a library, import the package and call Verify:
//
//	if !webhookverify.Verify(rawBody, r.Header.Get("X-Money-Signature"), secret) {
//	    http.Error(w, "bad sig", http.StatusUnauthorized)
//	    return
//	}
//
// As a CLI for cross-language testing — reads the raw body from stdin
// and exits 0 (valid) or 1 (invalid):
//
//	SIG="sha256=..." SECRET="..." go run verify.go

package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"io"
	"os"
	"strings"
)

// Verify reports whether sigHeader (with the "sha256=" prefix) is a valid
// HMAC-SHA256 of rawBody under secret. Constant-time comparison is used.
func Verify(rawBody []byte, sigHeader, secret string) bool {
	if !strings.HasPrefix(sigHeader, "sha256=") {
		return false
	}
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(rawBody)
	expected := "sha256=" + hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expected), []byte(sigHeader))
}

func main() {
	raw, err := io.ReadAll(os.Stdin)
	if err != nil {
		os.Exit(1)
	}
	sig := os.Getenv("SIG")
	secret := os.Getenv("SECRET")
	if Verify(raw, sig, secret) {
		os.Exit(0)
	}
	os.Exit(1)
}
