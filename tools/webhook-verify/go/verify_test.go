package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"testing"
)

const (
	testSecret = "test-secret-do-not-use"
	testBody   = `{"event":"webhook.test","occurredAt":"2026-05-01T00:00:00.000Z","payload":{"hello":"world"}}`
)

func goodSig(secret, body string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(body))
	return "sha256=" + hex.EncodeToString(mac.Sum(nil))
}

func TestVerify(t *testing.T) {
	cases := []struct {
		name     string
		body     string
		sig      string
		secret   string
		expected bool
	}{
		{"valid sig", testBody, goodSig(testSecret, testBody), testSecret, true},
		{"tampered body", testBody + "!", goodSig(testSecret, testBody), testSecret, false},
		{"wrong secret", testBody, goodSig(testSecret, testBody), "different-secret", false},
		{"missing prefix", testBody, goodSig(testSecret, testBody)[7:], testSecret, false},
		{"empty sig header", testBody, "", testSecret, false},
		{"empty body, valid sig", "", goodSig(testSecret, ""), testSecret, true},
	}

	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got := Verify([]byte(c.body), c.sig, c.secret)
			if got != c.expected {
				t.Errorf("expected %v, got %v", c.expected, got)
			}
		})
	}
}
