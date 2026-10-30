#!/bin/bash
# A small billing API that verifies bearer JWTs from an external issuer with
# PyJWT and serves account balances, committed, plus an uncommitted change that
# lets the partner dashboard apps call it with their own tokens.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p auth api
touch auth/__init__.py api/__init__.py
cat > requirements.txt <<'TXT'
PyJWT==2.15.1
cryptography==50.0.2
TXT
cat > .env.example <<'TXT'
AUTH_ISSUER=https://login.example.com/
API_AUDIENCE=https://api.example.com/billing
TXT
cat > auth/tokens.py <<'PY'
"""Verifies the bearer tokens callers send to this API."""

from __future__ import annotations

import os
from dataclasses import dataclass

import jwt

ISSUER = os.environ.get("AUTH_ISSUER", "https://login.example.com/")
API_AUDIENCE = os.environ.get("API_AUDIENCE", "https://api.example.com/billing")

_jwks = jwt.PyJWKClient(f"{ISSUER}.well-known/jwks.json", cache_keys=True)


class Unauthorized(Exception):
    pass


@dataclass(frozen=True)
class Principal:
    subject: str
    client_id: str
    scopes: frozenset[str]


def _bearer(request) -> str:
    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise Unauthorized("missing bearer token")
    return token


def verify(token: str) -> dict:
    try:
        key = _jwks.get_signing_key_from_jwt(token).key
        return jwt.decode(
            token,
            key,
            algorithms=["ES256"],
            audience=API_AUDIENCE,
            issuer=ISSUER,
            options={"require": ["exp", "iss", "aud", "sub"]},
        )
    except jwt.PyJWTError as exc:
        raise Unauthorized(str(exc)) from None


def authenticate(request) -> Principal:
    claims = verify(_bearer(request))
    return Principal(
        subject=claims["sub"],
        client_id=claims.get("azp", ""),
        scopes=frozenset(claims.get("scope", "").split()),
    )
PY
cat > api/accounts.py <<'PY'
"""Billing accounts. In memory here; the real store is a database table."""

from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal


@dataclass
class Account:
    account_id: str
    owner_subject: str
    balance: Decimal


_ACCOUNTS: dict[str, Account] = {}


def find(account_id: str) -> Account | None:
    return _ACCOUNTS.get(account_id)
PY
cat > api/handlers.py <<'PY'
"""Billing API handlers."""

from __future__ import annotations

from api import accounts
from auth.tokens import Principal, Unauthorized, authenticate


class Forbidden(Exception):
    pass


class NotFound(Exception):
    pass


def _require_scope(principal: Principal, scope: str) -> None:
    if scope not in principal.scopes:
        raise Forbidden(scope)


def get_balance(request, account_id: str) -> dict:
    principal = authenticate(request)
    _require_scope(principal, "billing:read")
    account = accounts.find(account_id)
    if account is None or account.owner_subject != principal.subject:
        raise NotFound(account_id)
    return {"account_id": account.account_id, "balance": str(account.balance)}


def handle(request, account_id: str) -> tuple[int, dict]:
    try:
        return 200, get_balance(request, account_id)
    except Unauthorized:
        return 401, {"error": "unauthorized"}
    except Forbidden:
        return 403, {"error": "forbidden"}
    except NotFound:
        return 404, {"error": "not found"}
PY
git add -A
git commit -qm "Add billing API with bearer token verification"

# The change under review: accept the partner dashboards' tokens.
cat >> .env.example <<'TXT'
# Comma-separated client IDs of the partner dashboard apps.
PARTNER_CLIENT_IDS=
TXT
cat > auth/tokens.py <<'PY'
"""Verifies the bearer tokens callers send to this API."""

from __future__ import annotations

import os
from dataclasses import dataclass

import jwt

ISSUER = os.environ.get("AUTH_ISSUER", "https://login.example.com/")
API_AUDIENCE = os.environ.get("API_AUDIENCE", "https://api.example.com/billing")
PARTNER_CLIENTS = frozenset(
    c.strip() for c in os.environ.get("PARTNER_CLIENT_IDS", "").split(",") if c.strip()
)

_jwks = jwt.PyJWKClient(f"{ISSUER}.well-known/jwks.json", cache_keys=True)


class Unauthorized(Exception):
    pass


@dataclass(frozen=True)
class Principal:
    subject: str
    client_id: str
    scopes: frozenset[str]


def _bearer(request) -> str:
    scheme, _, token = request.headers.get("Authorization", "").partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise Unauthorized("missing bearer token")
    return token


def verify(token: str) -> dict:
    """Claims of a token whose signature, issuer and expiry check out.

    The partner dashboards get their tokens from the same issuer, but the
    issuer mints those for the dashboard's own audience, so they never carry
    ours. They're recognized by their azp and checked without the audience.
    """
    try:
        unverified = jwt.decode(token, options={"verify_signature": False})
        key = _jwks.get_signing_key_from_jwt(token).key
        if unverified.get("azp") in PARTNER_CLIENTS:
            return jwt.decode(
                token,
                key,
                algorithms=["ES256"],
                issuer=ISSUER,
                options={"require": ["exp", "iss", "sub", "azp"], "verify_aud": False},
            )
        return jwt.decode(
            token,
            key,
            algorithms=["ES256"],
            audience=API_AUDIENCE,
            issuer=ISSUER,
            options={"require": ["exp", "iss", "aud", "sub"]},
        )
    except jwt.PyJWTError as exc:
        raise Unauthorized(str(exc)) from None


def authenticate(request) -> Principal:
    claims = verify(_bearer(request))
    return Principal(
        subject=claims["sub"],
        client_id=claims.get("azp", ""),
        scopes=frozenset(claims.get("scope", "").split()),
    )
PY
