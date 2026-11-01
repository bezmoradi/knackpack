#!/bin/bash
# A small Python accounts service on PostgreSQL 18 with an account_events
# history of about 600 million rows, indexed by id and created_at only. Today
# deleting an account only marks it deleted and keeps its events. The
# uncommitted change adds a foreign key from account_events.account_id to
# accounts with ON DELETE CASCADE (NOT VALID, then VALIDATE) and makes the
# DELETE /account handler delete the account row, so its events go with it. PostgreSQL doesn't
# index a foreign key's referencing column, so each account deletion's cascade
# scans all of account_events, which can't finish inside the service's 30
# second statement_timeout.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app db migrations

cat > README.md <<'MD'
# accounts

A small Python service that keeps user accounts and their activity history in
PostgreSQL 18.

## Data

`account_events` holds every account's activity history: about 600 million
rows, growing by about 2 million a day. Accounts that have been around for
years have hundreds of thousands of events each. `db/schema.sql` shows the
current schema.

## Deleting accounts

Users can delete their account from the settings page (`DELETE /account`,
`app/accounts.py`), a few hundred times a day. Today that only marks the
account deleted, and its events stay. The privacy team asked that deleting an
account erase its activity history too.

Every connection the service opens sets `statement_timeout` to 30 seconds
(`app/db.py`).

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql`. A migration that times out waiting for a lock is retried by the
deploy script.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
psycopg-pool>=3.2,<4
TXT

cat > db/schema.sql <<'SQL'
-- The current schema, for reference. The files in migrations/ change it.
CREATE TABLE accounts (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text        NOT NULL UNIQUE,
    deleted_at timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE account_events (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_id bigint      NOT NULL,
    kind       text        NOT NULL,
    payload    jsonb       NOT NULL DEFAULT '{}',
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX account_events_created_at_idx ON account_events (created_at);
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/db.py <<'PY'
"""Connections for the accounts service."""

import os

from psycopg_pool import ConnectionPool

pool = ConnectionPool(
    os.environ["DATABASE_URL"],
    min_size=2,
    max_size=20,
    kwargs={"options": "-c statement_timeout=30s"},
    open=False,
)
PY

cat > app/accounts.py <<'PY'
"""Account settings endpoints."""

from app.db import pool


def delete_account(account_id):
    """DELETE /account: the signed-in user deletes their account.

    The account is only marked deleted, so the user can't sign in again;
    its events are kept.
    """
    with pool.connection() as conn:
        conn.execute(
            "UPDATE accounts SET deleted_at = now()"
            " WHERE id = %s AND deleted_at IS NULL",
            (account_id,),
        )
PY

git add -A
git commit -qm "Accounts and their activity history"

cat > migrations/0011_account_events_fk.sql <<'SQL'
-- Events belong to their account: deleting an account deletes its history in
-- the same statement, as the privacy team asked. NOT VALID skips
-- checking the 600 million existing rows while holding the lock; 0012
-- validates them without blocking writes.
SET lock_timeout = '5s';

ALTER TABLE account_events
    ADD CONSTRAINT account_events_account_id_fkey
    FOREIGN KEY (account_id) REFERENCES accounts (id)
    ON DELETE CASCADE
    NOT VALID;
SQL

cat > migrations/0012_validate_account_events_fk.sql <<'SQL'
-- Takes SHARE UPDATE EXCLUSIVE, so reads and writes continue while it scans.
ALTER TABLE account_events VALIDATE CONSTRAINT account_events_account_id_fkey;
SQL

cat > app/accounts.py <<'PY'
"""Account settings endpoints."""

from app.db import pool


def delete_account(account_id):
    """DELETE /account: the signed-in user deletes their account.

    Deleting the account row deletes its events too, through the foreign key's
    ON DELETE CASCADE, so the account and its history are erased at once.
    """
    with pool.connection() as conn:
        conn.execute("DELETE FROM accounts WHERE id = %s", (account_id,))
PY

