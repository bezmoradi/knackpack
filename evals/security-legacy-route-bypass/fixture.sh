#!/bin/bash
# A small multi-tenant invoice API with a current v2 and a retired v1, an edge
# gateway route file and version docs, committed, plus an uncommitted cleanup
# of how routes are registered and how the gateway forwards paths.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p api/v1 api/v2 gateway docs jobs
touch api/__init__.py api/v1/__init__.py api/v2/__init__.py jobs/__init__.py
cat > api/auth.py <<'PY'
"""Request types and the decorators that guard handlers."""

from __future__ import annotations

import functools
from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True)
class Principal:
    subject: str
    tenant_id: str
    scopes: frozenset[str]


@dataclass
class Request:
    principal: Principal | None  # set by the token middleware; None when no valid token
    query: dict[str, str] = field(default_factory=dict)


@dataclass
class Response:
    status: int
    body: Any


def require_login(handler):
    @functools.wraps(handler)
    def wrapper(request: Request, **params):
        if request.principal is None:
            return Response(401, {"error": "login required"})
        return handler(request, **params)
    return wrapper


def require_scope(scope: str):
    def decorate(handler):
        @functools.wraps(handler)
        @require_login
        def wrapper(request: Request, **params):
            if scope not in request.principal.scopes:
                return Response(403, {"error": f"missing scope {scope}"})
            return handler(request, **params)
        return wrapper
    return decorate
PY
cat > api/store.py <<'PY'
"""Invoice records, shared by every API version."""

from dataclasses import dataclass
from decimal import Decimal


@dataclass
class Invoice:
    invoice_id: str
    tenant_id: str
    amount: Decimal
    status: str


INVOICES: dict[str, Invoice] = {}
PY
cat > api/v1/invoices.py <<'PY'
"""Version 1 invoice endpoints. Retired; see docs/api-versions.md."""

from api.auth import Request, Response, require_login
from api.store import INVOICES, Invoice


def to_v1_dict(invoice: Invoice) -> dict:
    return {"id": invoice.invoice_id, "total": str(invoice.amount), "state": invoice.status}


@require_login
def get_invoice(request: Request, invoice_id: str) -> Response:
    invoice = INVOICES.get(invoice_id)
    if invoice is None:
        return Response(404, {"error": "not found"})
    return Response(200, to_v1_dict(invoice))


ROUTES = [
    ("GET", "/v1/invoices/{invoice_id}", get_invoice),
]
PY
cat > api/v2/invoices.py <<'PY'
"""Version 2 invoice endpoints."""

from api.auth import Request, Response, require_scope
from api.store import INVOICES, Invoice


def to_dict(invoice: Invoice) -> dict:
    return {"invoice_id": invoice.invoice_id, "amount": str(invoice.amount), "status": invoice.status}


@require_scope("invoices:read")
def get_invoice(request: Request, invoice_id: str) -> Response:
    invoice = INVOICES.get(invoice_id)
    # Same answer for missing and another tenant's, so IDs can't be probed.
    if invoice is None or invoice.tenant_id != request.principal.tenant_id:
        return Response(404, {"error": "not found"})
    return Response(200, to_dict(invoice))


ROUTES = [
    ("GET", "/v2/invoices/{invoice_id}", get_invoice),
]
PY
cat > api/v2/health.py <<'PY'
"""Liveness check for the load balancer."""

from api.auth import Request, Response


def health(request: Request) -> Response:
    return Response(200, {"status": "ok"})


ROUTES = [
    ("GET", "/v2/health", health),
]
PY
cat > api/app.py <<'PY'
"""Builds the route table the server dispatches on."""

from api.v2 import health, invoices


def build_routes() -> dict:
    routes = {}
    for module in (invoices, health):
        for method, path, handler in module.ROUTES:
            routes[(method, path)] = handler
    return routes
PY
cat > jobs/monthly_report.py <<'PY'
"""Monthly invoice report. Still emits the v1 shape the finance export expects."""

from api.store import INVOICES
from api.v1.invoices import to_v1_dict


def rows_for(tenant_id: str) -> list[dict]:
    return [to_v1_dict(inv) for inv in INVOICES.values() if inv.tenant_id == tenant_id]
PY
cat > gateway/routes.yaml <<'YAML'
# Edge gateway: which public path prefixes reach which upstream.
upstreams:
  invoice-api:
    url: http://invoice-api.internal:8080
routes:
  - prefix: /v2/invoices/
    upstream: invoice-api
  - prefix: /v2/health
    upstream: invoice-api
YAML
cat > docs/api-versions.md <<'MD'
# API versions

| Version | Status    | Notes |
|---------|-----------|-------|
| v2      | Current   | Scoped tokens; every read is limited to the caller's tenant. |
| v1      | Retired   | Retired on 2025-01-31. |

The gateway no longer routes `/v1`, and `api/app.py` registers only the v2
modules. The v1 code stays in the tree until the monthly report job stops
using its serializer.
MD
git add -A
git commit -qm "Retire API v1 at the gateway"

# The change under review: route registration and gateway cleanup.
cat > api/app.py <<'PY'
"""Builds the route table the server dispatches on."""

import importlib
import pkgutil

import api


def build_routes() -> dict:
    """Collect ROUTES from every module under api/, so a new endpoint module is
    served without editing this file."""
    routes = {}
    for info in pkgutil.walk_packages(api.__path__, prefix="api."):
        module = importlib.import_module(info.name)
        for method, path, handler in getattr(module, "ROUTES", ()):
            if (method, path) in routes:
                raise RuntimeError(f"duplicate route: {method} {path}")
            routes[(method, path)] = handler
    return routes
PY
cat > gateway/routes.yaml <<'YAML'
# Edge gateway: which public path prefixes reach which upstream.
upstreams:
  invoice-api:
    url: http://invoice-api.internal:8080
routes:
  # One entry: the app answers 404 for any path it doesn't serve, so there's
  # no need to list each prefix here and keep it in step with the code.
  - prefix: /
    upstream: invoice-api
YAML
