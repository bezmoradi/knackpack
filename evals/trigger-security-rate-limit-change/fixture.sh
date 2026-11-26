#!/bin/bash
# A small FastAPI app with a login endpoint and no limit on failed attempts.
# The user asks for rate limiting to be added, a security-flavoured change
# request, not a request for a security or Python review.
set -euo pipefail
git init -q -b main
git config user.name "Noor Haddad"
git config user.email "noor@example.com"
mkdir -p app
cat > pyproject.toml <<'TOML'
[project]
name = "accounts"
version = "1.3.0"
requires-python = ">=3.11"
dependencies = ["fastapi>=0.110", "argon2-cffi>=23.1"]
TOML
cat > app/__init__.py <<'PY'
PY
cat > app/auth.py <<'PY'
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()
hasher = PasswordHasher()

# email -> password hash; the real app loads these from the database.
USERS: dict[str, str] = {}


class Login(BaseModel):
    email: str
    password: str


@router.post("/login")
def login(body: Login):
    stored = USERS.get(body.email.lower())
    try:
        if stored is None or not hasher.verify(stored, body.password):
            raise HTTPException(status_code=401, detail="invalid email or password")
    except VerifyMismatchError:
        raise HTTPException(status_code=401, detail="invalid email or password")
    return {"ok": True}
PY
cat > app/main.py <<'PY'
from fastapi import FastAPI

from .auth import router

app = FastAPI()
app.include_router(router)
PY
git add -A
git commit -qm "Login endpoint"
