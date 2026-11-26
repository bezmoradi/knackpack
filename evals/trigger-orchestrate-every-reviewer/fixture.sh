#!/bin/bash
# A small Python API with a feature branch that adds a CSV export of a
# team's orders. The user asks for every applicable reviewer at once and one
# merged report, which is Orchestrate review. The case lists no Agent tool, so
# the reviewers themselves can't start and the run stays cheap; it checks only
# that the skill is chosen.
set -euo pipefail
git init -q -b main
git config user.name "Noor Haddad"
git config user.email "noor@example.com"
mkdir -p app
cat > pyproject.toml <<'TOML'
[project]
name = "orders-api"
version = "0.4.0"
requires-python = ">=3.11"
dependencies = ["fastapi>=0.110", "sqlalchemy>=2.0"]
TOML
cat > app/db.py <<'PY'
from sqlalchemy import create_engine, text

engine = create_engine("sqlite:///orders.db")


def rows(sql: str, **params):
    with engine.connect() as conn:
        return [dict(r._mapping) for r in conn.execute(text(sql), params)]
PY
cat > app/main.py <<'PY'
from fastapi import Depends, FastAPI

from .auth import current_user
from .db import rows

app = FastAPI()


@app.get("/teams/{team_id}/orders")
def list_orders(team_id: int, user=Depends(current_user)):
    if team_id not in user.team_ids:
        return {"error": "forbidden"}
    return rows("SELECT id, total_cents FROM orders WHERE team_id = :t", t=team_id)
PY
cat > app/auth.py <<'PY'
from dataclasses import dataclass, field

from fastapi import Header


@dataclass
class User:
    id: int
    team_ids: set[int] = field(default_factory=set)


def current_user(x_user_id: int = Header()) -> User:
    return User(id=x_user_id, team_ids={x_user_id})
PY
git add -A
git commit -qm "Orders API"
git checkout -q -b orders-csv
cat > app/export.py <<'PY'
import csv
import io

from fastapi import Depends
from fastapi.responses import StreamingResponse

from .auth import current_user
from .db import rows
from .main import app


@app.get("/teams/{team_id}/orders.csv")
def export_orders(team_id: int, since: str = "1970-01-01", user=Depends(current_user)):
    data = rows(f"SELECT id, total_cents, created_at FROM orders WHERE team_id = {team_id} AND created_at >= '{since}'")
    buf = io.StringIO()
    w = csv.DictWriter(buf, fieldnames=["id", "total_cents", "created_at"])
    w.writeheader()
    w.writerows(data)
    buf.seek(0)
    return StreamingResponse(buf, media_type="text/csv")
PY
git add -A
git commit -qm "CSV export of a team's orders"
