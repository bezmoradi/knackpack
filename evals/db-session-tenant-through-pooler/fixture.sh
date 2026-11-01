#!/bin/bash
# A small Python notes service on PostgreSQL 18 for many workspaces, connected
# through PgBouncer in transaction mode, where row-level security limits the
# service's role to the workspace in app.workspace_id. Today each transaction
# sets it with set_config(..., true). The uncommitted change sets it once per
# request with set_config(..., false), on an autocommit connection, before the
# request's transactions. Through transaction pooling that session setting
# stays on whichever server connection ran it, and the request's later
# transactions run on server connections carrying other requests' workspaces,
# so notes are read and written across workspaces.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app deploy migrations

cat > README.md <<'MD'
# notes

A small Python service that keeps notes for many workspaces in PostgreSQL 18.

## Connections

Every process connects through PgBouncer in transaction mode
(`deploy/pgbouncer.ini`) as `notes_api`, which doesn't own the tables and
doesn't bypass row-level security.

## Workspace isolation

Row-level security on `notes` (migration 0005) limits `notes_api` to the
workspace in the setting `app.workspace_id`. The request handlers in
`app/handlers.py` don't filter by workspace themselves; they rely on the
policy.

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql`.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
psycopg-pool>=3.2,<4
TXT

cat > deploy/pgbouncer.ini <<'INI'
[databases]
notes = host=postgres.example.com port=5432 dbname=notes

[pgbouncer]
listen_addr = 0.0.0.0
listen_port = 6432
auth_type = scram-sha-256
auth_file = /etc/pgbouncer/userlist.txt
pool_mode = transaction
default_pool_size = 20
max_client_conn = 800
max_prepared_statements = 200
INI

cat > migrations/0001_notes.sql <<'SQL'
CREATE TABLE notes (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workspace_id bigint      NOT NULL,
    title        text        NOT NULL,
    body         text        NOT NULL,
    updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX notes_workspace_updated_idx ON notes (workspace_id, updated_at);
SQL

cat > migrations/0005_notes_rls.sql <<'SQL'
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY notes_workspace ON notes TO notes_api
    USING (workspace_id = (SELECT current_setting('app.workspace_id')::bigint));
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/db.py <<'PY'
"""Connections for the notes service."""

import os
from contextlib import contextmanager

from psycopg_pool import ConnectionPool

# DATABASE_URL points at PgBouncer, which runs in transaction mode.
pool = ConnectionPool(os.environ["DATABASE_URL"], min_size=2, max_size=20, open=False)


@contextmanager
def workspace_transaction(conn, workspace_id):
    """One transaction limited to one workspace by row-level security."""
    with conn.transaction():
        conn.execute(
            "SELECT set_config('app.workspace_id', %s, true)", (str(workspace_id),)
        )
        yield conn


@contextmanager
def request_connection():
    """The connection a request uses for all its transactions."""
    with pool.connection() as conn:
        conn.autocommit = True
        yield conn
PY

cat > app/handlers.py <<'PY'
"""Request handlers. Row-level security limits every query to the workspace."""

from app.db import request_connection, workspace_transaction


def list_notes(workspace_id):
    with request_connection() as conn:
        with workspace_transaction(conn, workspace_id):
            return conn.execute(
                "SELECT id, title, updated_at FROM notes"
                " ORDER BY updated_at DESC LIMIT 50"
            ).fetchall()


def save_note(workspace_id, note_id, title, body):
    with request_connection() as conn:
        with workspace_transaction(conn, workspace_id):
            conn.execute(
                "UPDATE notes SET title = %s, body = %s, updated_at = now()"
                " WHERE id = %s",
                (title, body, note_id),
            )
        with workspace_transaction(conn, workspace_id):
            return conn.execute(
                "SELECT id, title, body, updated_at FROM notes WHERE id = %s",
                (note_id,),
            ).fetchone()
PY

git add -A
git commit -qm "Notes isolated per workspace by row-level security"

cat > app/db.py <<'PY'
"""Connections for the notes service."""

import os
from contextlib import contextmanager

from psycopg_pool import ConnectionPool

# DATABASE_URL points at PgBouncer, which runs in transaction mode.
pool = ConnectionPool(os.environ["DATABASE_URL"], min_size=2, max_size=20, open=False)


@contextmanager
def workspace_connection(workspace_id):
    """The connection a request uses for all its transactions.

    Sets app.workspace_id once for the whole connection instead of at the start
    of every transaction, which saves a round trip per transaction. Row-level
    security reads it in every transaction the request runs.
    """
    with pool.connection() as conn:
        conn.autocommit = True
        conn.execute(
            "SELECT set_config('app.workspace_id', %s, false)", (str(workspace_id),)
        )
        yield conn
PY

cat > app/handlers.py <<'PY'
"""Request handlers. Row-level security limits every query to the workspace."""

from app.db import workspace_connection


def list_notes(workspace_id):
    with workspace_connection(workspace_id) as conn:
        with conn.transaction():
            return conn.execute(
                "SELECT id, title, updated_at FROM notes"
                " ORDER BY updated_at DESC LIMIT 50"
            ).fetchall()


def save_note(workspace_id, note_id, title, body):
    with workspace_connection(workspace_id) as conn:
        with conn.transaction():
            conn.execute(
                "UPDATE notes SET title = %s, body = %s, updated_at = now()"
                " WHERE id = %s",
                (title, body, note_id),
            )
        with conn.transaction():
            return conn.execute(
                "SELECT id, title, body, updated_at FROM notes WHERE id = %s",
                (note_id,),
            ).fetchone()
PY
