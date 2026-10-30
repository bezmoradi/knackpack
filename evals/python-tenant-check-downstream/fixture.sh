#!/bin/bash
# A multi-tenant app where tenant scoping lives in the query layer: a context
# variable holds the current tenant, middleware sets it from the verified
# session, and every query filters by it. The change adds a list view.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app

cat > pyproject.toml <<'TOML'
[project]
name = "projects-app"
version = "3.2.0"
requires-python = ">=3.10"
dependencies = []
TOML

cat > app/__init__.py <<'PY'
"""A small multi-tenant projects app."""
PY

cat > app/tenancy.py <<'PY'
"""The current tenant, carried per task in a context variable."""

from __future__ import annotations

from contextvars import ContextVar

_current_tenant: ContextVar = ContextVar("current_tenant")


class TenantNotSet(RuntimeError):
    """Raised when tenant-scoped work runs with no tenant in context."""


def set_current_tenant(tenant_id: str) -> None:
    _current_tenant.set(tenant_id)


def current_tenant() -> str:
    try:
        return _current_tenant.get()
    except LookupError as exc:
        raise TenantNotSet("no tenant in context") from exc
PY

cat > app/sessions.py <<'PY'
"""Verifies the signed session cookie and reads its claims."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
from dataclasses import dataclass


class InvalidSession(Exception):
    pass


@dataclass(frozen=True)
class Session:
    user_id: str
    tenant_id: str


def _signing_key() -> bytes:
    return os.environ["SESSION_SIGNING_KEY"].encode()


def _decode_signed(token: str) -> dict:
    try:
        body_b64, sig_b64 = token.split(".", 1)
    except ValueError as exc:
        raise InvalidSession("malformed token") from exc
    body = base64.urlsafe_b64decode(body_b64)
    want = hmac.new(_signing_key(), body, hashlib.sha256).digest()
    got = base64.urlsafe_b64decode(sig_b64)
    if not hmac.compare_digest(want, got):
        raise InvalidSession("bad signature")
    return json.loads(body)


def verify_session(request) -> Session:
    token = request.cookies.get("session")
    if not token:
        raise InvalidSession("missing session cookie")
    claims = _decode_signed(token)
    return Session(user_id=claims["sub"], tenant_id=claims["tenant"])
PY

cat > app/middleware.py <<'PY'
"""Sets the current tenant for each request from the verified session."""

from __future__ import annotations

from app.sessions import verify_session
from app.tenancy import set_current_tenant


class TenantMiddleware:
    def __init__(self, app):
        self._app = app

    def __call__(self, request):
        session = verify_session(request)
        set_current_tenant(session.tenant_id)
        return self._app(request)
PY

cat > app/models.py <<'PY'
"""Models whose queries are always scoped to the current tenant."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List

from app.tenancy import current_tenant


@dataclass(frozen=True)
class Project:
    project_id: str
    tenant_id: str
    name: str


# Stand-in for the backing table.
_ROWS: Dict[str, "Project"] = {}


class TenantScopedQuery:
    """Every read is filtered to current_tenant(); an unset tenant raises."""

    def __init__(self, rows: Dict[str, "Project"]):
        self._rows = rows

    def all(self) -> List["Project"]:
        tenant_id = current_tenant()
        return [row for row in self._rows.values() if row.tenant_id == tenant_id]

    def get(self, project_id: str) -> "Project":
        tenant_id = current_tenant()
        row = self._rows.get(project_id)
        if row is None or row.tenant_id != tenant_id:
            raise KeyError(project_id)
        return row


Project.objects = TenantScopedQuery(_ROWS)
PY

cat > app/views.py <<'PY'
"""HTTP views. Tenant scoping is enforced by the query layer, not here."""

from __future__ import annotations

from app.models import Project


def _serialize(project: Project) -> dict:
    return {"id": project.project_id, "name": project.name}


def get_project(request, project_id: str) -> dict:
    return _serialize(Project.objects.get(project_id))
PY

cat > README.md <<'MD'
# projects-app

Tenant isolation lives in the query layer. `TenantMiddleware` sets the current
tenant from the verified session, and `TenantScopedQuery` filters every read to
that tenant, raising if none is set. Views do not pass a tenant themselves.
MD

git add -A
git commit -qm "Add tenant scoping, middleware, models and the project view"

cat >> app/views.py <<'PY'


def list_projects(request) -> list:
    return [_serialize(p) for p in Project.objects.all()]
PY
