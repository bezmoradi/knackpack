#!/bin/bash
# A small Python invoicing app whose users sign in with email and password.
# notes/sso-request.md, from sales and customer success, gives the problem
# (large customers' IT can't cut off a departing employee's access in one
# place), who has it (account admins at customers with 200 or more seats who
# run Okta or Microsoft Entra ID) and the outcome (access removed in the
# identity provider stops sign-in, and the blocked renewals close). It also
# states success as "SSO live by end of November", which measures shipping rather
# than the outcome, and adds two asks no stated outcome needs: a rebranded
# login page and per-customer login themes. The PRD should tie requirements to
# the outcome, measure the outcome, and keep the two extra asks out of the
# requirements.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app docs notes

cat > README.md <<'MD'
# invoicer

A small Python web app that lets small businesses send invoices and track
payments.

Users sign in with their email address and a password (`app/auth.py`). Each
business has one account, and its owner can invite other users to it
(`app/accounts.py`). Sessions last 30 days (`app/sessions.py`).

Design notes and product documents live in `docs/`.
MD

cat > notes/sso-request.md <<'MD'
# SSO: what we've heard

Collected by sales and customer success, October 2026.

## From customers

- Three customers with 200 or more seats asked for single sign-on in the
  last quarter. Their IT teams run Okta (two of them) or Microsoft Entra ID
  (one).
- All three said the same thing: when someone leaves, IT disables them in
  the identity provider, but they can still sign in to invoicer with their
  password until someone remembers to remove them here. One customer found a
  former employee still signed in three weeks after leaving.
- Two of the three have renewals in December and told us they won't renew
  without it.

## Sales

Success = SSO live by end of November.

## Customer success

How we'd know it worked: when a customer's IT disables someone in Okta or
Entra ID, that person can no longer get into invoicer, and the two December
renewals close.

## Other asks that came up

- Design: while we're touching login anyway, refresh the login page with the
  new brand colors.
- One customer asked whether they could have their own logo and colors on the
  login page.
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

cat > app/sessions.py <<'PY'
"""Signed-in sessions."""

SESSION_DAYS = 30


def start_session(user_id):
    """Start a session that lasts SESSION_DAYS unless the user signs out."""
    raise NotImplementedError
PY

cat > app/accounts.py <<'PY'
"""Businesses and the users invited to them."""


def invite(business_id, email, role="member"):
    """Invite a user to a business by email."""
    raise NotImplementedError


def remove_user(business_id, user_id):
    """Remove a user from a business. Their open sessions end at once."""
    raise NotImplementedError
PY

git add -A
git commit -qm "Invoicer, with notes on the SSO request"
