#!/bin/bash
# A committed webhook module, plus an uncommitted change that is correct but
# looks odd at first sight: it rejects a missing or malformed header without
# comparing, compares signatures as bytes in constant time, and tests both.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app tests
cat > app/webhooks.py <<'PY'
"""Receives signed webhook deliveries."""

from __future__ import annotations

import hashlib
import hmac

SIGNATURE_PREFIX = "sha256="
PY
touch tests/__init__.py
git add -A
git commit -qm "Add webhooks module"
cat >> app/webhooks.py <<'PY'


def verify_signature(secret: bytes, body: bytes, header: str | None) -> bool:
    """True only when header is "sha256=<hex HMAC of body under secret>"."""
    # A missing or malformed header is rejected before any comparison.
    if not header or not header.startswith(SIGNATURE_PREFIX):
        return False
    expected = hmac.new(secret, body, hashlib.sha256).hexdigest()
    given = header[len(SIGNATURE_PREFIX):]
    # A real signature is ASCII hex, so anything else is a mismatch, and ASCII
    # bytes can't make compare_digest raise.
    if not given.isascii():
        return False
    # compare_digest takes the same time wherever the values differ.
    return hmac.compare_digest(expected.encode(), given.encode())
PY
cat > tests/test_webhooks.py <<'PY'
import hashlib
import hmac
import unittest

from app.webhooks import verify_signature

SECRET = b"test-secret"
BODY = b'{"event":"ping"}'
GOOD = "sha256=" + hmac.new(SECRET, BODY, hashlib.sha256).hexdigest()


class VerifySignature(unittest.TestCase):
    def test_accepts_a_valid_signature(self):
        self.assertTrue(verify_signature(SECRET, BODY, GOOD))

    def test_rejects_a_changed_body(self):
        self.assertFalse(verify_signature(SECRET, BODY + b" ", GOOD))

    def test_rejects_a_missing_or_malformed_header(self):
        for header in (None, "", "sha1=abc", GOOD[len("sha256="):], "sha256=" + "\u00e9" * 64, "sha256=\ud800"):
            self.assertFalse(verify_signature(SECRET, BODY, header))


if __name__ == "__main__":
    unittest.main()
PY
