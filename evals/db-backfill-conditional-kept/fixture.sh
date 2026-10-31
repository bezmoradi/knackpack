#!/bin/bash
# A small Python service on PostgreSQL whose customers can edit their display
# name at any time; migration 0007 added the nullable display_name column and
# every app instance already writes it. The uncommitted change adds a backfill
# script that runs one conditional UPDATE per id range, copying name only
# where display_name is still NULL, and advances its checkpoint after each
# commit, so it never overwrites a display name a customer set.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app db migrations scripts

cat > README.md <<'MD'
# customers

A small Python service that keeps the shop's customers in PostgreSQL 17.

## Display names

Customers can edit their display name at any time from their profile page,
and the app saves it in `customers.display_name` (`app/customers.py`).
Migration 0007 added that column as nullable. Every app instance already runs
the version that writes it, and a customer who signs up now gets their name as
their first display name.

Customers who signed up before 0007 still have no display name, and the app
shows their `name` instead. The next step is to backfill `display_name` from
`name` for them.

## Migrations and scripts

Migrations in `migrations/` are plain SQL files, applied in order with `psql`.
`db/schema.sql` shows the schema they produce. One-off data scripts live in
`scripts/` and run from an operator's shell with `DATABASE_URL` set, while the
app keeps serving customers.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
TXT

cat > db/schema.sql <<'SQL'
-- The schema after migration 0007, for reference. The files in migrations/
-- are what change the database.
CREATE TABLE customers (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name         text        NOT NULL,
    email        text        NOT NULL UNIQUE,
    display_name text,
    created_at   timestamptz NOT NULL DEFAULT now()
);
SQL

cat > migrations/0007_add_display_name.sql <<'SQL'
-- Customers can choose a display name. The column stays nullable until every
-- existing customer has one.
ALTER TABLE customers ADD COLUMN display_name text;
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/customers.py <<'PY'
"""Reads and writes customer rows.

Each function takes an open psycopg connection; the request handler that calls
it owns the transaction and commits once the request succeeds.
"""


def create_customer(conn, name, email):
    """Insert a customer, with their name as their first display name."""
    row = conn.execute(
        "INSERT INTO customers (name, email, display_name)"
        " VALUES (%s, %s, %s) RETURNING id",
        (name, email, name),
    ).fetchone()
    return row[0]


def set_display_name(conn, customer_id, display_name):
    """Save the display name a customer chose on their profile page."""
    display_name = display_name.strip()
    if not display_name:
        raise ValueError("display name must not be empty")
    conn.execute(
        "UPDATE customers SET display_name = %s WHERE id = %s",
        (display_name, customer_id),
    )


def display_name(conn, customer_id):
    """The name to show for a customer: their display name, else their name."""
    row = conn.execute(
        "SELECT coalesce(display_name, name) FROM customers WHERE id = %s",
        (customer_id,),
    ).fetchone()
    return row[0] if row else None
PY

git add -A
git commit -qm "Customers choose a display name"

cat > scripts/backfill_display_name.py <<'PY'
#!/usr/bin/env python3
"""Backfill customers.display_name from customers.name.

Copies each customer's name into display_name where display_name is still
NULL, one range of 1,000 ids at a time. Each range is one UPDATE that commits
on its own, and the end of each committed range is saved to a checkpoint file,
so a rerun after a failure resumes where it stopped.

    DATABASE_URL=postgresql://... python3 scripts/backfill_display_name.py
"""

import os
import sys
from pathlib import Path

import psycopg

BATCH_SIZE = 1000
CHECKPOINT = Path(
    os.environ.get("BACKFILL_CHECKPOINT", "backfill_display_name.checkpoint")
)


def load_checkpoint():
    try:
        return int(CHECKPOINT.read_text())
    except FileNotFoundError:
        return 0


def save_checkpoint(last_id):
    tmp = CHECKPOINT.with_name(CHECKPOINT.name + ".tmp")
    tmp.write_text(str(last_id))
    tmp.replace(CHECKPOINT)


def main():
    last_id = load_checkpoint()
    with psycopg.connect(os.environ["DATABASE_URL"], autocommit=True) as conn:
        # Customers who sign up from now on get a display name from the app,
        # so the backfill only has to reach the highest id that exists now.
        (max_id,) = conn.execute(
            "SELECT coalesce(max(id), 0) FROM customers"
        ).fetchone()
        while last_id < max_id:
            upper = min(last_id + BATCH_SIZE, max_id)
            with conn.transaction():
                cur = conn.execute(
                    "UPDATE customers SET display_name = name"
                    " WHERE id > %s AND id <= %s AND display_name IS NULL",
                    (last_id, upper),
                )
            last_id = upper
            save_checkpoint(last_id)
            print(
                f"backfilled through id {last_id} ({cur.rowcount} rows)",
                file=sys.stderr,
            )
    print("backfill complete", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
