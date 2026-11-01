#!/bin/bash
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"

# A Flask app served by gunicorn with four worker processes. Sessions live in
# Postgres. The user plans to move them into a module-level dict, which each
# worker process would hold separately.
cat > gunicorn.conf.py <<'EOF'
bind = "0.0.0.0:8000"
workers = 4
timeout = 30
EOF

cat > app.py <<'EOF'
import os
import secrets

import psycopg
from flask import Flask, abort, request

app = Flask(__name__)
DB_URL = os.environ["DATABASE_URL"]


def db():
    return psycopg.connect(DB_URL, autocommit=True)


@app.post("/login")
def login():
    user_id = check_password(request.form["email"], request.form["password"])
    if user_id is None:
        abort(401)
    token = secrets.token_urlsafe(32)
    with db() as conn:
        conn.execute("INSERT INTO sessions (token, user_id) VALUES (%s, %s)", (token, user_id))
    return {"token": token}


def current_user():
    token = request.headers.get("Authorization", "").removeprefix("Bearer ")
    with db() as conn:
        row = conn.execute("SELECT user_id FROM sessions WHERE token = %s", (token,)).fetchone()
    if row is None:
        abort(401)
    return row[0]


@app.get("/me")
def me():
    return {"user_id": current_user()}


def check_password(email, password):
    with db() as conn:
        row = conn.execute("SELECT id, password_hash FROM users WHERE email = %s", (email,)).fetchone()
    if row is None or not verify(password, row[1]):
        return None
    return row[0]


def verify(password, password_hash):
    from argon2 import PasswordHasher
    try:
        return PasswordHasher().verify(password_hash, password)
    except Exception:
        return False
EOF

cat > Procfile <<'EOF'
web: gunicorn -c gunicorn.conf.py app:app
EOF

git add -A
git commit -qm "Log in with a session token kept in Postgres"
