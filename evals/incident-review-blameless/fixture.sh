#!/bin/bash
# The orders service after the guest-order incident: Priya's commit tagged
# v1.4.2 broke the export for guest orders, Sam's commit on main fixed it
# with a regression test, and the CONFIRMED diagnosis is in
# incident/ROOT-CAUSE.md.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-18T10:00:00Z" GIT_COMMITTER_DATE="2026-11-18T10:00:00Z"
git init -q -b main
git config user.name "Priya Natarajan"
git config user.email "priya@example.com"
mkdir -p app tests incident
: > app/__init__.py
: > tests/__init__.py
cat > app/export.py <<'PY'
"""CSV export of orders for the finance team."""

import csv
import io


def export_rows(orders):
    """One row per order: id and total in dollars."""
    rows = []
    for order in orders:
        rows.append([order["id"], f"{order['total_cents'] / 100:.2f}"])
    return rows


def to_csv(orders):
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["id", "total"])
    for row in export_rows(orders):
        writer.writerow(row)
    return buf.getvalue()
PY
cat > tests/test_export.py <<'PY'
import unittest

from app.export import to_csv


class ExportTest(unittest.TestCase):
    def test_one_order(self):
        orders = [{"id": 1, "customer": {"email": "A@example.com"}, "total_cents": 1250}]
        self.assertIn("1,", to_csv(orders))


if __name__ == "__main__":
    unittest.main()
PY
git add -A && git commit -q -m "Export orders as CSV" && git tag v1.4.1
cat > app/export.py <<'PY'
"""CSV export of orders for the finance team."""

import csv
import io


def export_rows(orders):
    """One row per order: id, customer email, total in dollars."""
    rows = []
    for order in orders:
        email = order["customer"]["email"].lower()
        rows.append([order["id"], email, f"{order['total_cents'] / 100:.2f}"])
    return rows


def to_csv(orders):
    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(["id", "email", "total"])
    for row in export_rows(orders):
        writer.writerow(row)
    return buf.getvalue()
PY
sed -i.bak 's/self.assertIn("1,", to_csv(orders))/self.assertIn("1,a@example.com,12.50", to_csv(orders))/' tests/test_export.py && rm tests/test_export.py.bak
git add -A && git commit -q -m "Include the customer's email in the export" && git tag v1.4.2
cat > tests/test_export_guest.py <<'PY'
import unittest

from app.export import to_csv


class GuestOrderExportTest(unittest.TestCase):
    def test_guest_order_exports_with_empty_email(self):
        orders = [{"id": 7, "customer": None, "total_cents": 500}]
        self.assertIn("7,,5.00", to_csv(orders))


if __name__ == "__main__":
    unittest.main()
PY
python3 - <<'EDIT'
import re
p = "app/export.py"
s = open(p).read()
s = s.replace('        email = order["customer"]["email"].lower()\n', '        customer = order["customer"]\n        email = customer["email"].lower() if customer else ""\n')
open(p, "w").write(s)
EDIT
git config user.name "Sam Ortiz"
export GIT_AUTHOR_DATE="2026-11-20T09:30:00Z" GIT_COMMITTER_DATE="2026-11-20T09:30:00Z"
git config user.email "sam@example.com"
git add -A && git commit -q -m "Export guest orders with an empty email"
git config user.name "Priya Natarajan"
git config user.email "priya@example.com"
sha=$(git rev-parse v1.4.2)
sed "s/SHA_HERE/$sha/" > incident/ROOT-CAUSE.md <<'DOC'
# Root cause: orders CSV export returns 500 for guest orders

## Status

CONFIRMED

## Incident

- Task: guest-export-500
- Deployed revision: SHA_HERE (v1.4.2)
- Impact: `/admin/orders/export.csv` returned 500 for exports that include the failing orders, from 2026-11-19 22:41 UTC; finance couldn't pull their numbers. How many exports failed is unknown.
- Timeline: 2026-11-19 22:41:07 UTC, first 500 in the log (request 7f2c); 22:44:30 UTC, the same error again (request 81aa).
- Symptom: `TypeError: 'NoneType' object is not subscriptable` at `app/export.py:11`, in `export_rows`, and a 500 from the export.

## Evidence

- incident/app.log, 2026-11-19T22:41:07.611Z: the traceback above, ending in `export_rows`.
- incident/app.log, 2026-11-19T22:41:07.530Z: a database pool warning at 82% of 50 connections.

## Missing evidence

- How many exports failed, and for whom.

## Reproduction

`tests/test_export_guest.py`, run with `python3 -m unittest tests.test_export_guest`. At the deployed SHA it fails with the same TypeError from `export_rows`.

```python
import unittest

from app.export import to_csv


class GuestOrderExportTest(unittest.TestCase):
    def test_guest_order_exports_with_empty_email(self):
        orders = [{"id": 7, "customer": None, "total_cents": 500}]
        self.assertIn("7,,5.00", to_csv(orders))


if __name__ == "__main__":
    unittest.main()
```

## Hypotheses

1. `export_rows` (`app/export.py:11`, at the deployed SHA) reads `order["customer"]["email"]`, and guest orders carry `"customer": None`. For: the traceback's last frame is that line, and the commit tagged v1.4.2 added it. Against: none found. Test: an order with `"customer": None` raises the same TypeError from `export_rows` at v1.4.2, and exports at v1.4.1. Result: supported.
2. Database pool exhaustion (`WARN db pool usage at 82%` at 22:41:07.530Z). For: the warning comes just before the error. Against: the error is a TypeError raised inside `export_rows`, not a pool timeout, and 82% isn't exhaustion. Result: ruled out.

## Cause

The commit tagged v1.4.2 added `email = order["customer"]["email"].lower()` to `export_rows` (`app/export.py:11`). Guest orders carry `"customer": None`, so any export that includes one raises TypeError and the request returns 500. Contributing factor: `tests/test_export.py` covers only an order with a customer.

## Remaining uncertainty

- What finance expects in the email column for a guest order; the reproduction assumes an empty value.
DOC
