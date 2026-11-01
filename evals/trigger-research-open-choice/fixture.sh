#!/bin/bash
# A small Python web app that keeps sessions in Postgres. Every request looks
# its session up by token, and the token column has no index, so each lookup
# scans the table; every request also rewrites the session's last_seen. Both
# are cheaper to fix than moving sessions to Redis, which the user asks about.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"

cat > README.md <<'EOF'
# accounts-web

The customer accounts site. Sessions live in the `sessions` table in Postgres,
created by `schema.sql`; `sessions.py` reads and updates them on every request.
EOF

cat > schema.sql <<'EOF'
CREATE TABLE users (
    id         bigserial PRIMARY KEY,
    email      text NOT NULL UNIQUE
);

CREATE TABLE sessions (
    id         bigserial PRIMARY KEY,
    user_id    bigint NOT NULL REFERENCES users (id),
    token      text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    last_seen  timestamptz NOT NULL DEFAULT now()
);
EOF

cat > sessions.py <<'EOF'
"""Session lookup, called by the middleware on every request."""

import secrets


def create_session(conn, user_id):
    token = secrets.token_urlsafe(32)
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO sessions (user_id, token) VALUES (%s, %s)",
            (user_id, token),
        )
    conn.commit()
    return token


def load_session(conn, token):
    """Return the session's user id, or None. Runs on every request."""
    with conn.cursor() as cur:
        cur.execute("SELECT id, user_id FROM sessions WHERE token = %s", (token,))
        row = cur.fetchone()
        if row is None:
            return None
        session_id, user_id = row
        cur.execute("UPDATE sessions SET last_seen = now() WHERE id = %s", (session_id,))
    conn.commit()
    return user_id
EOF

cat > middleware.py <<'EOF'
from sessions import load_session


def session_middleware(app, connect):
    def wrapped(environ, start_response):
        token = environ.get("HTTP_COOKIE", "").removeprefix("session=")
        conn = connect()
        try:
            environ["user_id"] = load_session(conn, token) if token else None
        finally:
            conn.close()
        return app(environ, start_response)

    return wrapped
EOF

git add -A
git commit -qm "Accounts site with Postgres sessions"
