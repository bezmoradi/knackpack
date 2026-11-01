#!/bin/bash
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"

# Sessions are looked up by token on every request, and the sessions table has
# no index on token. The user's plan to add one is sound.
mkdir -p migrations
cat > migrations/001_sessions.sql <<'EOF'
CREATE TABLE sessions (
    id BIGSERIAL PRIMARY KEY,
    token TEXT NOT NULL,
    user_id BIGINT NOT NULL REFERENCES users (id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
EOF

cat > app.py <<'EOF'
import os

import psycopg
from flask import Flask, abort, request

app = Flask(__name__)
DB_URL = os.environ["DATABASE_URL"]


def current_user():
    token = request.headers.get("Authorization", "").removeprefix("Bearer ")
    with psycopg.connect(DB_URL, autocommit=True) as conn:
        row = conn.execute("SELECT user_id FROM sessions WHERE token = %s", (token,)).fetchone()
    if row is None:
        abort(401)
    return row[0]


@app.get("/me")
def me():
    return {"user_id": current_user()}
EOF

git add -A
git commit -qm "Look sessions up by token"
