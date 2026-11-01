#!/bin/bash
# A small Python catalog service on PostgreSQL 18 that caches prices in each
# process's memory with no expiry; a trigger sends NOTIFY price_changed and a
# listener thread in each process drops the changed product from its cache.
# The uncommitted change puts PgBouncer in transaction mode in front of the
# database and points DATABASE_URL at it, without touching the listener, which
# runs LISTEN on a connection from the same pool. LISTEN never works through
# transaction pooling, so the caches stop being invalidated and keep serving
# old prices.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app deploy migrations

cat > README.md <<'MD'
# catalog

A small Python service that serves product prices from PostgreSQL 18.

## Price cache

Each process keeps prices in memory (`app/cache.py`) with no expiry, because
prices are read on every page and change a few hundred times a day. When a
price changes, the trigger from migration 0003 sends `NOTIFY price_changed`
with the product's id, and each process's listener thread
(`app/listener.py`) drops that product from its cache, so the next read
loads the new price.

## Deployment

`deploy/app.env` holds the environment for the 40 service processes. Each
process opens one connection pool from `DATABASE_URL` (`app/db.py`), and the
listener thread takes its connection from that pool.

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql`.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
psycopg-pool>=3.2,<4
TXT

cat > migrations/0001_products.sql <<'SQL'
CREATE TABLE products (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sku         text   NOT NULL UNIQUE,
    name        text   NOT NULL,
    price_cents bigint NOT NULL CHECK (price_cents >= 0)
);
SQL

cat > migrations/0003_price_changed_notify.sql <<'SQL'
CREATE FUNCTION notify_price_changed() RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM pg_notify('price_changed', NEW.id::text);
    RETURN NEW;
END
$$;

CREATE TRIGGER products_price_changed
    AFTER UPDATE OF price_cents ON products
    FOR EACH ROW
    WHEN (OLD.price_cents IS DISTINCT FROM NEW.price_cents)
    EXECUTE FUNCTION notify_price_changed();
SQL

cat > deploy/app.env <<'ENV'
DATABASE_URL=postgresql://postgres.example.com:5432/catalog?user=catalog_api
DATABASE_POOL_MAX=10
ENV

cat > app/__init__.py <<'PY'
PY

cat > app/db.py <<'PY'
"""The process's connection pool."""

import os

from psycopg_pool import ConnectionPool

pool = ConnectionPool(
    os.environ["DATABASE_URL"],
    min_size=2,
    max_size=int(os.environ.get("DATABASE_POOL_MAX", "10")),
    open=False,
)
PY

cat > app/cache.py <<'PY'
"""Prices cached in this process's memory, without expiry.

The listener thread drops a product when its price changes, so a cached price
is never older than the last change it was told about.
"""

import threading

from app.db import pool

_lock = threading.Lock()
_prices = {}


def price(product_id):
    with _lock:
        if product_id in _prices:
            return _prices[product_id]
    with pool.connection() as conn:
        row = conn.execute(
            "SELECT price_cents FROM products WHERE id = %s", (product_id,)
        ).fetchone()
    if row is None:
        return None
    with _lock:
        _prices[product_id] = row[0]
    return row[0]


def drop(product_id):
    with _lock:
        _prices.pop(product_id, None)
PY

cat > app/listener.py <<'PY'
"""Drops products from this process's price cache when their price changes."""

import logging
import threading

from app import cache
from app.db import pool

log = logging.getLogger(__name__)


def _listen():
    while True:
        try:
            with pool.connection() as conn:
                conn.autocommit = True
                conn.execute("LISTEN price_changed")
                for note in conn.notifies():
                    cache.drop(int(note.payload))
        except Exception:
            log.exception("price listener failed; reconnecting")


def start():
    threading.Thread(target=_listen, name="price-listener", daemon=True).start()
PY

git add -A
git commit -qm "Catalog with an in-memory price cache"

cat > deploy/pgbouncer.ini <<'INI'
; Forty processes with ten connections each went past max_connections at
; peak, so every process now connects through PgBouncer, which multiplexes
; them over a small pool of server connections.
[databases]
catalog = host=postgres.example.com port=5432 dbname=catalog

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
default_pool_size = 25
max_client_conn = 1000
; psycopg prepares statements it runs repeatedly; PgBouncer tracks them.
max_prepared_statements = 200
INI

cat > deploy/app.env <<'ENV'
DATABASE_URL=postgresql://pgbouncer.example.com:6432/catalog?user=catalog_api
DATABASE_POOL_MAX=10
ENV
