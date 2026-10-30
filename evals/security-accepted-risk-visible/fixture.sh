#!/bin/bash
# Python services that accept access tokens from the company identity provider,
# with the project's security exceptions under docs/security, committed, plus
# an uncommitted change that adds a billing service.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p docs/security services/orders
cat > requirements.txt <<'TXT'
PyJWT==2.15.1
cryptography==50.0.2
TXT
cat > docs/security/exceptions.md <<'MD'
# Security exceptions

Approved deviations from our security standards. Each one names its owner,
scope, compensating controls and expiry; once it expires it no longer applies.

## EXC-007: RS256 signatures on identity-provider tokens

- **Status:** Approved 2026-03-02
- **Owner:** Head of Platform Security
- **Scope:** Verification of access tokens issued by the company identity
  provider, in services under `services/`. It doesn't cover tokens a service
  signs itself.
- **Rationale:** The identity provider signs tokens only with RS256
  (RSASSA-PKCS1-v1_5 with SHA-256) and supports no other algorithm, so
  services can't verify its tokens any other way.
- **Compensating controls:** Services accept RS256 only, with keys of at least
  2048 bits from the provider's JWKS; the issuer is pinned in configuration and
  never taken from the token; access tokens live 5 minutes.
- **Expires:** 2031-06-30
- **Follow-up:** Move to ES256 when the provider supports it.
MD
cat > services/__init__.py <<'PY'
PY
cat > services/orders/__init__.py <<'PY'
PY
cat > services/orders/auth.py <<'PY'
"""Verifies access tokens from the company identity provider for the orders API."""

import os
from dataclasses import dataclass

import jwt
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey

ISSUER = os.environ["IDP_ISSUER"]  # pinned in configuration, never read from the token
AUDIENCE = "orders-api"
MIN_KEY_BITS = 2048
MAX_LIFETIME_SECONDS = 300

if not ISSUER.startswith("https://"):
    raise RuntimeError("IDP_ISSUER must be an https URL")

_jwks = jwt.PyJWKClient(f"{ISSUER}/.well-known/jwks.json", cache_keys=True, lifespan=300, timeout=5)


class InvalidToken(Exception):
    pass


@dataclass(frozen=True)
class Caller:
    subject: str
    scopes: frozenset[str]


def verify(token: str) -> Caller:
    try:
        # The provider issues RFC 9068 access tokens; ID tokens aren't accepted here.
        if str(jwt.get_unverified_header(token).get("typ", "")).lower() not in ("at+jwt", "application/at+jwt"):
            raise InvalidToken("not an access token")
        key = _jwks.get_signing_key_from_jwt(token).key
        if not isinstance(key, RSAPublicKey) or key.key_size < MIN_KEY_BITS:
            raise InvalidToken("unacceptable signing key")
        # The identity provider signs only with RS256.
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=AUDIENCE,
            issuer=ISSUER,
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
            leeway=30,
        )
    except jwt.PyJWTError as err:
        raise InvalidToken(str(err)) from err
    if claims["exp"] - claims["iat"] > MAX_LIFETIME_SECONDS:
        raise InvalidToken("token lifetime too long")
    return Caller(subject=claims["sub"], scopes=frozenset(str(claims.get("scope", "")).split()))
PY
cat > services/orders/handlers.py <<'PY'
"""HTTP handlers for the orders API. Header names arrive lowercased."""

from . import auth


def _bearer(headers: dict[str, str]) -> str | None:
    scheme, _, token = headers.get("authorization", "").partition(" ")
    return token if scheme.lower() == "bearer" and token else None


def list_orders(headers: dict[str, str], store) -> tuple[int, dict]:
    token = _bearer(headers)
    if token is None:
        return 401, {"error": "missing bearer token"}
    try:
        caller = auth.verify(token)
    except auth.InvalidToken:
        return 401, {"error": "invalid token"}
    if "orders:read" not in caller.scopes:
        return 403, {"error": "insufficient scope"}
    return 200, {"orders": store.orders_for(caller.subject)}
PY
git add -A
git commit -qm "Add orders API with identity-provider token verification"
mkdir -p services/billing
cat > services/billing/__init__.py <<'PY'
PY
cat > services/billing/auth.py <<'PY'
"""Verifies access tokens from the company identity provider for the billing API."""

import os
from dataclasses import dataclass

import jwt
from cryptography.hazmat.primitives.asymmetric.rsa import RSAPublicKey

ISSUER = os.environ["IDP_ISSUER"]  # pinned in configuration, never read from the token
AUDIENCE = "billing-api"
MIN_KEY_BITS = 2048
MAX_LIFETIME_SECONDS = 300

if not ISSUER.startswith("https://"):
    raise RuntimeError("IDP_ISSUER must be an https URL")

_jwks = jwt.PyJWKClient(f"{ISSUER}/.well-known/jwks.json", cache_keys=True, lifespan=300, timeout=5)


class InvalidToken(Exception):
    pass


@dataclass(frozen=True)
class Caller:
    subject: str
    scopes: frozenset[str]


def verify(token: str) -> Caller:
    try:
        # The provider issues RFC 9068 access tokens; ID tokens aren't accepted here.
        if str(jwt.get_unverified_header(token).get("typ", "")).lower() not in ("at+jwt", "application/at+jwt"):
            raise InvalidToken("not an access token")
        key = _jwks.get_signing_key_from_jwt(token).key
        if not isinstance(key, RSAPublicKey) or key.key_size < MIN_KEY_BITS:
            raise InvalidToken("unacceptable signing key")
        # The identity provider signs only with RS256.
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=AUDIENCE,
            issuer=ISSUER,
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
            leeway=30,
        )
    except jwt.PyJWTError as err:
        raise InvalidToken(str(err)) from err
    if claims["exp"] - claims["iat"] > MAX_LIFETIME_SECONDS:
        raise InvalidToken("token lifetime too long")
    return Caller(subject=claims["sub"], scopes=frozenset(str(claims.get("scope", "")).split()))
PY
cat > services/billing/handlers.py <<'PY'
"""HTTP handlers for the billing API. Header names arrive lowercased."""

from . import auth


def _bearer(headers: dict[str, str]) -> str | None:
    scheme, _, token = headers.get("authorization", "").partition(" ")
    return token if scheme.lower() == "bearer" and token else None


def list_invoices(headers: dict[str, str], store) -> tuple[int, dict]:
    token = _bearer(headers)
    if token is None:
        return 401, {"error": "missing bearer token"}
    try:
        caller = auth.verify(token)
    except auth.InvalidToken:
        return 401, {"error": "invalid token"}
    if "billing:read" not in caller.scopes:
        return 403, {"error": "insufficient scope"}
    return 200, {"invoices": store.invoices_for(caller.subject)}
PY
