#!/bin/bash
# A small Python team-invite service on PostgreSQL 18. Users are soft-deleted,
# and an email is unique only among live users, through the partial unique
# index users_email_live ... WHERE deleted_at IS NULL. The uncommitted change
# replaces the invite's SELECT-then-INSERT with INSERT ... ON CONFLICT (email)
# DO UPDATE. That conflict target doesn't repeat the index's predicate, so it
# matches no unique index or constraint and PostgreSQL rejects every invite.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app migrations

cat > README.md <<'MD'
# team-invites

A small Python service that manages the members of a team workspace, in
PostgreSQL 18.

## Users and emails

Removing a user only sets `users.deleted_at`. An email can be used again after
its user is removed, so uniqueness covers live users only: migration 0004
added the partial unique index `users_email_live`.

## Invites

Admins invite people by email from the members page (`app/invites.py`).
Inviting an email that already belongs to a live user refreshes their
`invited_at` and sends the invite again; otherwise it creates the user.

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql`.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
TXT

cat > migrations/0001_users.sql <<'SQL'
CREATE TABLE users (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email      text        NOT NULL,
    name       text,
    invited_at timestamptz,
    joined_at  timestamptz,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_key ON users (email);
SQL

cat > migrations/0004_soft_delete_users.sql <<'SQL'
-- Removing a user keeps their row for the audit trail, and their email can be
-- invited again, so the email only has to be unique among live users.
ALTER TABLE users ADD COLUMN deleted_at timestamptz;
CREATE UNIQUE INDEX users_email_live ON users (email) WHERE deleted_at IS NULL;
DROP INDEX users_email_key;
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/invites.py <<'PY'
"""Invites from the members page."""


def invite(conn, email):
    """Invite an email address, returning the user's id.

    Inviting an email that already belongs to a live user refreshes their
    invited_at, so the invite is sent again.
    """
    email = email.strip().lower()
    row = conn.execute(
        "SELECT id FROM users WHERE email = %s AND deleted_at IS NULL",
        (email,),
    ).fetchone()
    if row is not None:
        conn.execute(
            "UPDATE users SET invited_at = now() WHERE id = %s", (row[0],)
        )
        return row[0]
    (user_id,) = conn.execute(
        "INSERT INTO users (email, invited_at) VALUES (%s, now()) RETURNING id",
        (email,),
    ).fetchone()
    return user_id
PY

git add -A
git commit -qm "Invites, with users removed softly"

cat > app/invites.py <<'PY'
"""Invites from the members page."""


def invite(conn, email):
    """Invite an email address, returning the user's id.

    Inviting an email that already belongs to a live user refreshes their
    invited_at, so the invite is sent again. One statement, so two admins
    inviting the same address at once no longer race between the lookup and
    the insert.
    """
    email = email.strip().lower()
    (user_id,) = conn.execute(
        "INSERT INTO users (email, invited_at) VALUES (%s, now())"
        " ON CONFLICT (email) DO UPDATE SET invited_at = excluded.invited_at"
        " RETURNING id",
        (email,),
    ).fetchone()
    return user_id
PY
