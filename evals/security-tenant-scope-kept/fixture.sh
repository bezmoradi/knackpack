#!/bin/bash
# A small multi-tenant invoicing service whose storage is reached through a
# repository bound to one tenant, committed, plus an uncommitted change that
# adds a paginated list of overdue invoices.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app
touch app/__init__.py
cat > app/context.py <<'PY'
"""Who is calling. The tenant comes only from the verified session."""

from dataclasses import dataclass


@dataclass(frozen=True)
class VerifiedSession:
    """Built by the auth middleware once it has checked the session's signature and expiry."""

    user_id: str
    tenant_id: str


@dataclass(frozen=True)
class CurrentUser:
    user_id: str
    tenant_id: str


def current_user(session: VerifiedSession) -> CurrentUser:
    # Takes the session, not the request, so no query or body field can pick the tenant.
    return CurrentUser(user_id=session.user_id, tenant_id=session.tenant_id)
PY
cat > app/db.py <<'PY'
"""Invoice storage. Every read and write goes through a repository bound to one tenant."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from decimal import Decimal

from app.context import CurrentUser


@dataclass(frozen=True)
class Invoice:
    invoice_id: str
    tenant_id: str
    status: str
    amount: Decimal
    due_date: date


_ROWS: list[Invoice] = []


class TenantScopedRepo:
    """Invoices of one tenant. It has no method that reads across tenants."""

    def __init__(self, tenant_id: str) -> None:
        if not tenant_id:
            raise ValueError("tenant_id is required")
        self._tenant_id = tenant_id

    def _rows(self) -> list[Invoice]:
        return [row for row in _ROWS if row.tenant_id == self._tenant_id]

    def get(self, invoice_id: str) -> Invoice | None:
        return next((row for row in self._rows() if row.invoice_id == invoice_id), None)

    def find(self, status: str | None = None) -> list[Invoice]:
        rows = self._rows()
        if status is not None:
            rows = [row for row in rows if row.status == status]
        return sorted(rows, key=lambda row: row.invoice_id)

    def add(self, invoice: Invoice) -> None:
        if invoice.tenant_id != self._tenant_id:
            raise ValueError("invoice belongs to another tenant")
        _ROWS.append(invoice)


def repo_for(user: CurrentUser) -> TenantScopedRepo:
    return TenantScopedRepo(user.tenant_id)
PY
cat > app/invoices.py <<'PY'
"""Invoice use cases."""

from __future__ import annotations

from app.context import CurrentUser
from app.db import Invoice, repo_for


class NotFound(Exception):
    pass


def get_invoice(user: CurrentUser, invoice_id: str) -> Invoice:
    invoice = repo_for(user).get(invoice_id)
    if invoice is None:
        raise NotFound(invoice_id)
    return invoice


def list_paid(user: CurrentUser) -> list[Invoice]:
    return repo_for(user).find(status="paid")
PY
cat > app/routes.py <<'PY'
"""HTTP routes for invoices."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable

from app import invoices
from app.context import VerifiedSession, current_user
from app.db import Invoice


@dataclass
class Request:
    session: VerifiedSession  # set by the auth middleware, which runs before every route
    path_params: dict[str, str] = field(default_factory=dict)
    query: dict[str, str] = field(default_factory=dict)


@dataclass
class Response:
    status: int
    body: Any


Handler = Callable[[Request], Response]
ROUTES: dict[tuple[str, str], Handler] = {}


def route(method: str, path: str) -> Callable[[Handler], Handler]:
    def register(handler: Handler) -> Handler:
        ROUTES[(method, path)] = handler
        return handler
    return register


def _invoice_json(invoice: Invoice) -> dict[str, str]:
    return {
        "invoice_id": invoice.invoice_id,
        "status": invoice.status,
        "amount": str(invoice.amount),
        "due_date": invoice.due_date.isoformat(),
    }


@route("GET", "/invoices/{invoice_id}")
def show_invoice(request: Request) -> Response:
    user = current_user(request.session)
    try:
        invoice = invoices.get_invoice(user, request.path_params["invoice_id"])
    except invoices.NotFound:
        return Response(404, {"error": "not found"})
    return Response(200, _invoice_json(invoice))


@route("GET", "/reports/paid-invoices")
def paid_invoices(request: Request) -> Response:
    user = current_user(request.session)
    return Response(200, {"invoices": [_invoice_json(i) for i in invoices.list_paid(user)]})
PY
git add -A
git commit -qm "Add tenant-scoped invoice repository and routes"

# The change under review: a paginated overdue report.
cat > app/invoices.py <<'PY'
"""Invoice use cases."""

from __future__ import annotations

from datetime import date

from app.context import CurrentUser
from app.db import Invoice, repo_for

DEFAULT_PAGE_SIZE = 50
MAX_PAGE_SIZE = 100


class NotFound(Exception):
    pass


def get_invoice(user: CurrentUser, invoice_id: str) -> Invoice:
    invoice = repo_for(user).get(invoice_id)
    if invoice is None:
        raise NotFound(invoice_id)
    return invoice


def list_paid(user: CurrentUser) -> list[Invoice]:
    return repo_for(user).find(status="paid")


def list_overdue(user: CurrentUser, page: int, page_size: int, today: date | None = None) -> list[Invoice]:
    """Return all overdue invoices, one page at a time, oldest due date first."""
    if page < 0:
        raise ValueError("page must be 0 or more")
    page_size = max(1, min(page_size, MAX_PAGE_SIZE))
    today = today or date.today()
    all_rows = repo_for(user).find(status="issued")
    overdue = sorted(
        (row for row in all_rows if row.due_date < today),
        key=lambda row: (row.due_date, row.invoice_id),
    )
    start = page * page_size
    return overdue[start:start + page_size]
PY
cat >> app/routes.py <<'PY'


@route("GET", "/reports/overdue-invoices")
def overdue_invoices(request: Request) -> Response:
    user = current_user(request.session)
    try:
        page = int(request.query.get("page", "0"))
        page_size = int(request.query.get("page_size", str(invoices.DEFAULT_PAGE_SIZE)))
    except ValueError:
        return Response(400, {"error": "page and page_size must be whole numbers"})
    try:
        rows = invoices.list_overdue(user, page, page_size)
    except ValueError as exc:
        return Response(400, {"error": str(exc)})
    return Response(200, {"page": page, "invoices": [_invoice_json(i) for i in rows]})
PY
