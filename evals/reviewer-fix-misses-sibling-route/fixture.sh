#!/bin/bash
# A small FastAPI invoicing service where each invoice belongs to one tenant,
# with a CSV export for accounting integrations, committed, plus an uncommitted
# fix for an incident in which a customer read another company's invoice.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app docs/incidents
touch app/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "invoicing"
version = "3.4.0"
requires-python = ">=3.11"
dependencies = ["fastapi>=0.115", "pydantic>=2.9"]
TOML
cat > app/models.py <<'PY'
from dataclasses import asdict, dataclass


@dataclass(frozen=True)
class User:
    user_id: str
    tenant_id: str


@dataclass(frozen=True)
class Invoice:
    invoice_id: str
    tenant_id: str
    number: str
    customer_email: str
    total_cents: int

    def to_dict(self) -> dict:
        return asdict(self)
PY
cat > app/repository.py <<'PY'
from app.models import Invoice


class InvoiceRepository:
    def __init__(self, db) -> None:
        self.db = db

    def get(self, invoice_id: str) -> Invoice | None:
        row = self.db.fetch_one(
            "select invoice_id, tenant_id, number, customer_email, total_cents"
            " from invoices where invoice_id = %s",
            (invoice_id,),
        )
        return Invoice(**row) if row else None
PY
cat > app/deps.py <<'PY'
from fastapi import Request

from app.models import User
from app.repository import InvoiceRepository


def current_user(request: Request) -> User:
    # Set by the session middleware after it validates the session cookie.
    return request.state.user


def invoice_repo(request: Request) -> InvoiceRepository:
    return InvoiceRepository(request.app.state.db)
PY
cat > app/routes.py <<'PY'
from fastapi import APIRouter, Depends, HTTPException

from app.deps import current_user, invoice_repo
from app.models import User
from app.repository import InvoiceRepository

router = APIRouter()


@router.get("/invoices/{invoice_id}")
def get_invoice(
    invoice_id: str,
    user: User = Depends(current_user),
    repo: InvoiceRepository = Depends(invoice_repo),
) -> dict:
    invoice = repo.get(invoice_id)
    if invoice is None:
        raise HTTPException(status_code=404)
    return invoice.to_dict()
PY
cat > app/exports.py <<'PY'
"""Bulk export for the accounting integrations: a CSV of the invoices asked for."""

import csv
import io

from fastapi import APIRouter, Depends, Response
from pydantic import BaseModel

from app.deps import current_user, invoice_repo
from app.models import User
from app.repository import InvoiceRepository

router = APIRouter()


class ExportRequest(BaseModel):
    invoice_ids: list[str]


@router.post("/exports/invoices.csv")
def export_invoices(
    body: ExportRequest,
    user: User = Depends(current_user),
    repo: InvoiceRepository = Depends(invoice_repo),
) -> Response:
    out = io.StringIO()
    writer = csv.writer(out)
    writer.writerow(["number", "customer_email", "total"])
    for invoice_id in body.invoice_ids[:500]:
        invoice = repo.get(invoice_id)
        if invoice is not None:
            writer.writerow([invoice.number, invoice.customer_email, invoice.total_cents / 100])
    return Response(out.getvalue(), media_type="text/csv")
PY
cat > app/main.py <<'PY'
from fastapi import FastAPI

from app import exports, routes

app = FastAPI()
app.include_router(routes.router)
app.include_router(exports.router)
PY
cat > docs/incidents/INC-0142.md <<'MD'
# INC-0142: a customer saw another company's invoice

A signed-in user changed the id in `/invoices/<id>` in the browser's address
bar and was shown an invoice that belongs to a different tenant, including the
customer's email address and the total. Invoice ids are sequential-looking and
appear in emails, so other ids are easy to guess.

Cause: `get_invoice` loads the invoice by id alone and never compares its
tenant with the signed-in user's tenant.

Requirement: users only ever see their own tenant's invoices.
MD
git add -A
git commit -q -m "Invoices API and accounting export"

# The uncommitted fix for INC-0142.
cat > app/routes.py <<'PY'
from fastapi import APIRouter, Depends, HTTPException

from app.deps import current_user, invoice_repo
from app.models import User
from app.repository import InvoiceRepository

router = APIRouter()


@router.get("/invoices/{invoice_id}")
def get_invoice(
    invoice_id: str,
    user: User = Depends(current_user),
    repo: InvoiceRepository = Depends(invoice_repo),
) -> dict:
    invoice = repo.get(invoice_id)
    # INC-0142: hide invoices of other tenants. 404, not 403, so ids of other
    # tenants' invoices can't be confirmed by probing.
    if invoice is None or invoice.tenant_id != user.tenant_id:
        raise HTTPException(status_code=404)
    return invoice.to_dict()
PY
