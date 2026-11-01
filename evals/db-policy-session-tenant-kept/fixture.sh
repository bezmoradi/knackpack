#!/bin/bash
# A small Python orders service on PostgreSQL 18 for many shops, connected
# through PgBouncer in transaction mode, where every query already filters by
# shop_id. The uncommitted change adds row-level security as a second line of
# defense: the policy compares shop_id with (SELECT current_setting(...)),
# which the planner runs once, on columns an index already leads with, and
# the service sets the shop with set_config(..., true) inside each request's
# transaction, so the setting ends with the transaction and never reaches
# another client through the pooler. Nothing about the policy is a defect.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app db deploy jobs migrations

cat > README.md <<'MD'
# orders

A small Python service that keeps orders for many shops in PostgreSQL 18.

## Connections

Every process connects through PgBouncer in transaction mode
(`deploy/pgbouncer.ini`), as the role `orders_api` (`db/roles.sql`), which
doesn't own the tables and doesn't bypass row-level security. Each request
runs in one transaction opened by `shop_transaction` in `app/db.py`, and
every code path that touches orders goes through it, including the nightly
export, which opens one per shop (`jobs/export.py`).

## Shop isolation

Every query in `app/orders.py` filters by `shop_id`. Row-level security on
`orders` is meant as a second line of defense, so that a query that forgets
the filter still can't read another shop's orders.

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql` as `orders_owner`. A migration that times out waiting for a lock is
retried by the deploy script.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
psycopg-pool>=3.2,<4
TXT

cat > db/roles.sql <<'SQL'
-- Run once per environment by an administrator, before the migrations.
CREATE ROLE orders_owner LOGIN;
CREATE ROLE orders_api LOGIN;
GRANT CREATE ON SCHEMA public TO orders_owner;
SQL

cat > deploy/pgbouncer.ini <<'INI'
[databases]
orders = host=postgres.example.com port=5432 dbname=orders

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
default_pool_size = 20
max_client_conn = 500
max_prepared_statements = 200
INI

cat > migrations/0001_orders.sql <<'SQL'
CREATE TABLE orders (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    shop_id     bigint      NOT NULL,
    customer    text        NOT NULL,
    total_cents bigint      NOT NULL,
    status      text        NOT NULL DEFAULT 'new',
    created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_shop_created_idx ON orders (shop_id, created_at);

GRANT USAGE ON SCHEMA public TO orders_api;
GRANT SELECT, INSERT, UPDATE ON orders TO orders_api;
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/db.py <<'PY'
"""Connections for the orders service."""

import os
from contextlib import contextmanager

from psycopg_pool import ConnectionPool

# DATABASE_URL points at PgBouncer, which runs in transaction mode.
pool = ConnectionPool(os.environ["DATABASE_URL"], min_size=2, max_size=20, open=False)


@contextmanager
def shop_transaction(shop_id):
    """Run one request's work for one shop in a single transaction."""
    with pool.connection() as conn:
        with conn.transaction():
            yield conn
PY

cat > app/orders.py <<'PY'
"""Order reads and writes, always inside shop_transaction."""


def recent_orders(conn, shop_id, limit=50):
    return conn.execute(
        "SELECT id, customer, total_cents, status, created_at FROM orders"
        " WHERE shop_id = %s ORDER BY created_at DESC, id DESC LIMIT %s",
        (shop_id, limit),
    ).fetchall()


def create_order(conn, shop_id, customer, total_cents):
    (order_id,) = conn.execute(
        "INSERT INTO orders (shop_id, customer, total_cents)"
        " VALUES (%s, %s, %s) RETURNING id",
        (shop_id, customer, total_cents),
    ).fetchone()
    return order_id


def mark_shipped(conn, shop_id, order_id):
    conn.execute(
        "UPDATE orders SET status = 'shipped' WHERE id = %s AND shop_id = %s",
        (order_id, shop_id),
    )
PY

cat > jobs/__init__.py <<'PY'
PY

cat > jobs/export.py <<'PY'
"""Nightly export: one CSV of yesterday's orders per shop."""

import csv
import sys

from app.db import pool, shop_transaction


def export_shop(shop_id, out):
    with shop_transaction(shop_id) as conn:
        rows = conn.execute(
            "SELECT id, customer, total_cents, status, created_at FROM orders"
            " WHERE shop_id = %s AND created_at >= current_date - 1"
            " AND created_at < current_date ORDER BY id",
            (shop_id,),
        ).fetchall()
    writer = csv.writer(out)
    writer.writerows(rows)


def main(shop_ids):
    pool.open()
    for shop_id in shop_ids:
        with open(f"orders-{shop_id}.csv", "w", newline="") as out:
            export_shop(shop_id, out)


if __name__ == "__main__":
    main([int(arg) for arg in sys.argv[1:]])
PY

git add -A
git commit -qm "Orders service on PgBouncer"

cat > migrations/0002_orders_rls.sql <<'SQL'
-- A second line of defense: orders_api sees and writes only the shop in
-- app.shop_id, which shop_transaction sets for each request's transaction.
-- current_setting() raises an error when the setting doesn't exist, and an
-- empty one fails the cast to bigint, so a query run without a shop fails
-- instead of returning every shop's orders.
SET lock_timeout = '5s';

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- The subquery makes the planner read the setting once per query rather than
-- once per row, and orders_shop_created_idx already leads with shop_id.
CREATE POLICY orders_shop ON orders TO orders_api
    USING (shop_id = (SELECT current_setting('app.shop_id')::bigint));
SQL

cat > app/db.py <<'PY'
"""Connections for the orders service."""

import os
from contextlib import contextmanager

from psycopg_pool import ConnectionPool

# DATABASE_URL points at PgBouncer, which runs in transaction mode.
pool = ConnectionPool(os.environ["DATABASE_URL"], min_size=2, max_size=20, open=False)


@contextmanager
def shop_transaction(shop_id):
    """Run one request's work for one shop in a single transaction.

    Sets app.shop_id for the row-level security policy on orders. The third
    argument to set_config makes the setting end with this transaction, so it
    stays on this transaction's server connection only while we use it and
    never carries over to another client through PgBouncer.
    """
    with pool.connection() as conn:
        with conn.transaction():
            conn.execute(
                "SELECT set_config('app.shop_id', %s, true)", (str(shop_id),)
            )
            yield conn
PY
