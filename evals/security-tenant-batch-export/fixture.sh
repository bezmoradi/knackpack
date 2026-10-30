#!/bin/bash
# A small multi-tenant invoicing service (models, an in-memory store, invoice
# use cases and a route table), committed, plus an uncommitted change that adds
# a CSV export of several invoices at once.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app
touch app/__init__.py
cat > app/models.py <<'PY'
"""Records the invoicing service works with."""

from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class User:
    user_id: str
    tenant_id: str


@dataclass
class Invoice:
    invoice_id: str
    tenant_id: str
    status: str
    amount: Decimal
PY
cat > app/store.py <<'PY'
"""Invoice storage. This in-memory version stands in for the database adapter."""

from __future__ import annotations

from typing import Iterable

from app.models import Invoice


class InvoiceStore:
    def __init__(self) -> None:
        self._rows: dict[str, Invoice] = {}

    def add(self, invoice: Invoice) -> None:
        self._rows[invoice.invoice_id] = invoice

    def get(self, invoice_id: str) -> Invoice | None:
        return self._rows.get(invoice_id)

    def get_many(self, invoice_ids: Iterable[str]) -> list[Invoice]:
        """The invoices with these IDs, in the order given. Unknown IDs are skipped."""
        found = []
        for invoice_id in invoice_ids:
            invoice = self._rows.get(invoice_id)
            if invoice is not None:
                found.append(invoice)
        return found


store = InvoiceStore()
PY
cat > app/invoices.py <<'PY'
"""Invoice use cases."""

from __future__ import annotations

from app.models import Invoice, User
from app.store import store


class NotFound(Exception):
    pass


def get_invoice(user: User, invoice_id: str) -> Invoice:
    invoice = store.get(invoice_id)
    # One answer for "missing" and "another tenant's", so IDs can't be probed.
    if invoice is None or invoice.tenant_id != user.tenant_id:
        raise NotFound(invoice_id)
    return invoice
PY
cat > app/routes.py <<'PY'
"""Maps request paths to invoice handlers."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable

from app import invoices
from app.models import User


@dataclass
class Request:
    user: User  # set by the session middleware from the verified session
    path_params: dict[str, str] = field(default_factory=dict)
    body: dict[str, Any] = field(default_factory=dict)


@dataclass
class Response:
    status: int
    body: Any
    content_type: str = "application/json"


def show_invoice(request: Request) -> Response:
    try:
        invoice = invoices.get_invoice(request.user, request.path_params["invoice_id"])
    except invoices.NotFound:
        return Response(404, {"error": "not found"})
    return Response(200, {
        "invoice_id": invoice.invoice_id,
        "status": invoice.status,
        "amount": str(invoice.amount),
    })


ROUTES: dict[tuple[str, str], Callable[[Request], Response]] = {
    ("GET", "/invoices/{invoice_id}"): show_invoice,
}
PY
git add -A
git commit -qm "Add invoice lookup service"

# The change under review: a CSV export of several invoices.
cat > app/invoices.py <<'PY'
"""Invoice use cases."""

from __future__ import annotations

import csv
import io
import logging

from app.models import Invoice, User
from app.store import store

logger = logging.getLogger(__name__)

EXPORTABLE_STATUSES = frozenset({"issued", "paid", "overdue"})
MAX_EXPORT_IDS = 500


class NotFound(Exception):
    pass


def get_invoice(user: User, invoice_id: str) -> Invoice:
    invoice = store.get(invoice_id)
    # One answer for "missing" and "another tenant's", so IDs can't be probed.
    if invoice is None or invoice.tenant_id != user.tenant_id:
        raise NotFound(invoice_id)
    return invoice


def export_invoices(user: User, invoice_ids: list[str]) -> str:
    """CSV of the requested invoices, leaving out drafts and voided ones.

    The batch is read with one get_many call: going through get_invoice costs a
    store round trip per ID, which makes a large export slow on the database
    adapter.
    """
    if len(invoice_ids) > MAX_EXPORT_IDS:
        raise ValueError(f"at most {MAX_EXPORT_IDS} invoices per export")
    rows = [inv for inv in store.get_many(invoice_ids) if inv.status in EXPORTABLE_STATUSES]
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["invoice_id", "status", "amount"])
    for inv in rows:
        writer.writerow([inv.invoice_id, inv.status, f"{inv.amount:.2f}"])
    logger.info("user %s exported %d invoices", user.user_id, len(rows))
    return out.getvalue()
PY
cat > app/routes.py <<'PY'
"""Maps request paths to invoice handlers."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Callable

from app import invoices
from app.models import User


@dataclass
class Request:
    user: User  # set by the session middleware from the verified session
    path_params: dict[str, str] = field(default_factory=dict)
    body: dict[str, Any] = field(default_factory=dict)


@dataclass
class Response:
    status: int
    body: Any
    content_type: str = "application/json"


def show_invoice(request: Request) -> Response:
    try:
        invoice = invoices.get_invoice(request.user, request.path_params["invoice_id"])
    except invoices.NotFound:
        return Response(404, {"error": "not found"})
    return Response(200, {
        "invoice_id": invoice.invoice_id,
        "status": invoice.status,
        "amount": str(invoice.amount),
    })


def export_invoices(request: Request) -> Response:
    ids = request.body.get("invoice_ids")
    if not isinstance(ids, list) or not all(isinstance(i, str) for i in ids):
        return Response(400, {"error": "invoice_ids must be a list of strings"})
    try:
        csv_text = invoices.export_invoices(request.user, ids)
    except ValueError as exc:
        return Response(400, {"error": str(exc)})
    return Response(200, csv_text, content_type="text/csv")


ROUTES: dict[tuple[str, str], Callable[[Request], Response]] = {
    ("GET", "/invoices/{invoice_id}"): show_invoice,
    ("POST", "/invoices/export"): export_invoices,
}
PY
