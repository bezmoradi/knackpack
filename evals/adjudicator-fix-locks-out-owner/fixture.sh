#!/bin/bash
# A small Python invoice service where any signed-in user can read any
# company's invoice, a review note reporting it, and an uncommitted fix that
# compares the invoice's company with the user's own ID.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p billing tests
touch billing/__init__.py tests/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "billing"
version = "0.14.0"
requires-python = ">=3.11"
TOML
cat > README.md <<'MD'
# billing

Each company (tenant) sees only its own invoices; every user belongs to one
company. Run the tests with `python3 -m unittest` from the repository root.
MD
cat > billing/store.py <<'PY'
"""In-memory data for the invoice service."""

USERS = {
    "u-17": {"id": "u-17", "tenant_id": "t-acme", "name": "Priya"},
    "u-42": {"id": "u-42", "tenant_id": "t-globex", "name": "Tom"},
}

INVOICES = {
    "inv-1001": {"id": "inv-1001", "tenant_id": "t-acme", "total_cents": 125000},
    "inv-2001": {"id": "inv-2001", "tenant_id": "t-globex", "total_cents": 98000},
}
PY
cat > billing/invoices.py <<'PY'
from billing.store import INVOICES


class NotFound(Exception):
    pass


class Forbidden(Exception):
    pass


def get_invoice(user: dict, invoice_id: str) -> dict:
    """Return one invoice for the signed-in user."""
    invoice = INVOICES.get(invoice_id)
    if invoice is None:
        raise NotFound(invoice_id)
    return invoice
PY
cat > review-notes.md <<'MD'
# Review notes

F1 (High): `get_invoice` in billing/invoices.py returns any invoice by ID to
any signed-in user, so a Globex user can read Acme's invoices.
MD
git add -A
git commit -q -m "Invoice lookup"

# The uncommitted fix for F1, with its test.
cat > billing/invoices.py <<'PY'
from billing.store import INVOICES


class NotFound(Exception):
    pass


class Forbidden(Exception):
    pass


def get_invoice(user: dict, invoice_id: str) -> dict:
    """Return one invoice for the signed-in user, if it's their company's."""
    invoice = INVOICES.get(invoice_id)
    if invoice is None:
        raise NotFound(invoice_id)
    if invoice["tenant_id"] != user["id"]:
        raise Forbidden(invoice_id)
    return invoice
PY
cat > tests/test_invoices.py <<'PY'
import unittest

from billing.invoices import Forbidden, get_invoice
from billing.store import USERS


class InvoiceAccessTest(unittest.TestCase):
    def test_other_company_cannot_read_invoice(self):
        with self.assertRaises(Forbidden):
            get_invoice(USERS["u-42"], "inv-1001")
PY
