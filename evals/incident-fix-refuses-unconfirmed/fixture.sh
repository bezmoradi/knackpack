#!/bin/bash
# The orders service from incident-debug-triage-only, at v1.4.2, with a
# diagnosis in incident/ROOT-CAUSE.md whose Status is UNCONFIRMED: two
# causes are still plausible, so no fix may start.
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
sha=$(git rev-parse v1.4.2)
sed "s/SHA_HERE/$sha/" > incident/ROOT-CAUSE.md <<'DOC'
# Root cause: orders CSV export returns 500 for guest orders

## Status

UNCONFIRMED

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

1. `export_rows` (`app/export.py:11`, at the deployed SHA) reads `order["customer"]["email"]`, and some orders may carry `"customer": None`. For: the traceback's last frame is that line. Against: the export's query is supposed to exclude guest orders, and nobody has confirmed what production's orders hold. Test: not yet run against production-shaped data.
2. A deleted customer leaves `customer` null on old orders after a data cleanup on 2026-11-19. For: the cleanup ran that afternoon. Against: no record of which orders it touched. Test: none possible without the cleanup's log.

## Cause



## Remaining uncertainty

- Whether guest orders reach the export at all, and which orders the cleanup changed.
DOC
