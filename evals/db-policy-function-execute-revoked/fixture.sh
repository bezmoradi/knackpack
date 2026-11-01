#!/bin/bash
# A small Python service on PostgreSQL 18 that shares documents within teams.
# Row-level security on documents calls private.is_team_member, a SECURITY
# DEFINER function, for the service's role docs_api. The uncommitted change is
# a hardening migration that revokes EXECUTE on that function from docs_api so
# the API can't call it directly. A policy runs with the privileges of the
# role running the query, so every query docs_api runs on documents then fails
# with "permission denied for function is_team_member".
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app db migrations

cat > README.md <<'MD'
# docs

A small Python service that stores documents shared within teams, in
PostgreSQL 18.

## Access

The service connects as `docs_api` (`db/roles.sql`), which doesn't own the
tables and doesn't bypass row-level security. At the start of each request's
transaction it sets `app.user_id` to the signed-in user. The policy on
`documents` (migration 0003) lets `docs_api` see a document only when that
user belongs to the document's team. The membership check is
`private.is_team_member`, a `SECURITY DEFINER` function, because `docs_api`
can't read `team_members` itself.

The documents API in `app/documents.py` is the product's main page: every
request lists or reads documents.

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql` as `docs_owner`.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
TXT

cat > db/roles.sql <<'SQL'
-- Run once per environment by an administrator, before the migrations.
CREATE ROLE docs_owner LOGIN;
CREATE ROLE docs_api LOGIN;
GRANT CREATE ON SCHEMA public TO docs_owner;
GRANT CREATE ON DATABASE docs TO docs_owner;
SQL

cat > migrations/0001_tables.sql <<'SQL'
CREATE TABLE teams (
    id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE team_members (
    team_id bigint NOT NULL REFERENCES teams (id),
    user_id bigint NOT NULL,
    PRIMARY KEY (team_id, user_id)
);
CREATE INDEX team_members_user_idx ON team_members (user_id, team_id);

CREATE TABLE documents (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    team_id    bigint      NOT NULL REFERENCES teams (id),
    title      text        NOT NULL,
    body       text        NOT NULL,
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX documents_team_idx ON documents (team_id, updated_at);
SQL

cat > migrations/0002_api_grants.sql <<'SQL'
GRANT USAGE ON SCHEMA public TO docs_api;
GRANT SELECT, INSERT, UPDATE ON documents TO docs_api;
SQL

cat > migrations/0003_documents_rls.sql <<'SQL'
CREATE SCHEMA private;

-- Reads team_members as docs_owner, since docs_api has no access to it.
CREATE FUNCTION private.is_team_member(p_team_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.team_members
         WHERE team_id = p_team_id
           AND user_id = current_setting('app.user_id')::bigint
    )
$$;

REVOKE EXECUTE ON FUNCTION private.is_team_member(bigint) FROM PUBLIC;
GRANT USAGE ON SCHEMA private TO docs_api;
GRANT EXECUTE ON FUNCTION private.is_team_member(bigint) TO docs_api;

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY documents_team ON documents TO docs_api
    USING (private.is_team_member(team_id));
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/documents.py <<'PY'
"""Document reads and writes.

Each function takes an open psycopg connection inside the request's
transaction, after the request handler has set app.user_id for it. Row-level
security limits every query to the teams the user belongs to.
"""


def list_documents(conn, limit=50):
    return conn.execute(
        "SELECT id, team_id, title, updated_at FROM documents"
        " ORDER BY updated_at DESC, id DESC LIMIT %s",
        (limit,),
    ).fetchall()


def get_document(conn, document_id):
    return conn.execute(
        "SELECT id, team_id, title, body, updated_at FROM documents WHERE id = %s",
        (document_id,),
    ).fetchone()


def rename_document(conn, document_id, title):
    conn.execute(
        "UPDATE documents SET title = %s, updated_at = now() WHERE id = %s",
        (title, document_id),
    )
PY

git add -A
git commit -qm "Documents visible only to their team's members"

cat > migrations/0004_lock_down_membership_check.sql <<'SQL'
-- Security review follow-up: the API shouldn't be able to call the
-- membership check directly and probe which teams a user belongs to. The
-- policy on documents keeps using it, and policies are evaluated by the
-- database, so the API role doesn't need EXECUTE.
REVOKE EXECUTE ON FUNCTION private.is_team_member(bigint) FROM docs_api;
SQL
