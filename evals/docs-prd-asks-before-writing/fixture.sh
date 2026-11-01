#!/bin/bash
# A small Python invoicing app whose users sign in with email and password.
# Nothing in the repository says why SSO is wanted, who is asking for it, or
# how anyone would judge that it worked, and the request doesn't either. A PRD
# written now would be built on guesses, so Write docs should ask for those
# facts before writing one.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app docs

cat > README.md <<'MD'
# invoicer

A small Python web app that lets small businesses send invoices and track
payments.

Users sign in with their email address and a password (`app/auth.py`). Each
business has one account, and its owner can invite other users to it
(`app/accounts.py`).

Design notes and product documents live in `docs/`.
MD

cat > docs/invoice-numbering.md <<'MD'
# Invoice numbering

Each business numbers its invoices from 1 with an optional prefix, such as
`INV-`. Numbers are never reused, even after an invoice is deleted, because
tax rules in several of our customers' countries require an unbroken
sequence.
MD

cat > app/__init__.py <<'PY'
PY

cat > app/auth.py <<'PY'
"""Email and password sign-in."""

import hashlib
import hmac


def check_password(stored_hash, salt, password):
    """Compare a password with the stored PBKDF2 hash in constant time."""
    candidate = hashlib.pbkdf2_hmac("sha256", password.encode(), salt, 600_000)
    return hmac.compare_digest(candidate, stored_hash)
PY

cat > app/accounts.py <<'PY'
"""Businesses and the users invited to them."""


def invite(business_id, email, role="member"):
    """Invite a user to a business by email."""
    raise NotImplementedError
PY

git add -A
git commit -qm "Invoicer"
