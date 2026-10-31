#!/bin/bash
# An orders service on PostgreSQL 17 whose schema is managed by Alembic, with
# env.py running every pending migration inside the transaction that
# context.begin_transaction() opens. The uncommitted change adds a revision
# that builds an index on the busy orders table with
# postgresql_concurrently=True but no autocommit_block(), so CREATE INDEX
# CONCURRENTLY runs inside Alembic's transaction, which PostgreSQL rejects.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app migrations/versions

cat > README.md <<'MD'
# orders

Keeps the shop's orders in PostgreSQL 17. The `orders` table has about 200
million rows and takes writes all day, from checkout and from the fulfilment
workers.

## Migrations

Schema changes are Alembic revisions in `migrations/versions/`. The deploy
pipeline runs them against the production database, with `DATABASE_URL` set,
before it rolls out the new app version:

    alembic upgrade head
MD

cat > requirements.txt <<'TXT'
alembic>=1.13,<2
SQLAlchemy>=2.0,<3
psycopg[binary]>=3.2,<4
TXT

cat > alembic.ini <<'INI'
# Alembic reads this file. The database URL comes from DATABASE_URL, which
# migrations/env.py reads, so no credentials live here.
[alembic]
script_location = migrations
INI

cat > migrations/env.py <<'PY'
"""Alembic's entry point: runs the revisions against DATABASE_URL."""

import os

from alembic import context
from sqlalchemy import create_engine, pool


def database_url():
    return os.environ["DATABASE_URL"]


def run_offline():
    """Print the SQL instead of running it (alembic upgrade --sql)."""
    context.configure(url=database_url(), literal_binds=True)
    with context.begin_transaction():
        context.run_migrations()


def run_online():
    """Connect to the database and run the pending revisions."""
    engine = create_engine(database_url(), poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_offline()
else:
    run_online()
PY

cat > migrations/versions/0001_create_orders.py <<'PY'
"""Create the orders table.

Revision ID: 0001
Create Date: 2025-03-02
"""

import sqlalchemy as sa
from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "orders",
        sa.Column("id", sa.BigInteger, sa.Identity(always=True), primary_key=True),
        sa.Column("tenant_id", sa.BigInteger, nullable=False),
        sa.Column("status", sa.Text, nullable=False),
        sa.Column("total_cents", sa.BigInteger, nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.func.now(),
        ),
    )


def downgrade():
    op.drop_table("orders")
PY

cat > app/__init__.py <<'PY'
PY

cat > app/orders.py <<'PY'
"""Queries on the orders table."""

from sqlalchemy import text

RECENT_ORDERS = text(
    "SELECT id, status, total_cents, created_at FROM orders"
    " WHERE tenant_id = :tenant_id"
    " ORDER BY created_at DESC"
    " LIMIT :limit"
)


def recent_orders(conn, tenant_id, limit=50):
    """A tenant's newest orders, for the order history page."""
    return conn.execute(RECENT_ORDERS, {"tenant_id": tenant_id, "limit": limit}).all()
PY

git add -A
git commit -qm "Orders table, managed by Alembic"

cat > migrations/versions/0002_index_orders_tenant_created.py <<'PY'
"""Index orders by tenant and creation time, for the order history page.

Revision ID: 0002
Revises: 0001
Create Date: 2026-10-30
"""

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade():
    # orders is large and busy: build the index without blocking writes.
    op.create_index(
        "ix_orders_tenant_created",
        "orders",
        ["tenant_id", "created_at"],
        postgresql_concurrently=True,
    )


def downgrade():
    op.drop_index(
        "ix_orders_tenant_created",
        table_name="orders",
        postgresql_concurrently=True,
    )
PY
