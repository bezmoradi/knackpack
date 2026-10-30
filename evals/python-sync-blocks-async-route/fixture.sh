#!/bin/bash
# A small FastAPI service that serves reports fetched from an internal report
# renderer with requests, committed, plus an uncommitted endpoint that
# downloads a report's PDF export.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app
touch app/__init__.py
cat > pyproject.toml <<'TOML'
[project]
name = "reports-api"
version = "0.6.0"
requires-python = ">=3.11"
dependencies = [
    "fastapi==0.115.6",
    "requests==2.34.2",
    "uvicorn==0.32.1",
]
TOML
cat > app/settings.py <<'PY'
"""Configuration from the environment."""

import os

RENDERER_URL = os.environ.get("RENDERER_URL", "http://report-renderer.internal:8080")
API_KEYS = frozenset(k for k in os.environ.get("API_KEYS", "").split(",") if k)
PY
cat > app/auth.py <<'PY'
"""API key check for the report endpoints."""

import hmac

from fastapi import Header, HTTPException

from app import settings


def require_api_key(x_api_key: str = Header()) -> None:
    given = x_api_key.encode()
    if not any(hmac.compare_digest(given, key.encode()) for key in settings.API_KEYS):
        raise HTTPException(status_code=401, detail="invalid API key")
PY
cat > app/reports_client.py <<'PY'
"""Client for the internal report renderer."""

from typing import Any

import requests

from app import settings


def fetch_report(report_id: int) -> dict[str, Any]:
    response = requests.get(f"{settings.RENDERER_URL}/reports/{report_id}", timeout=10)
    response.raise_for_status()
    return response.json()
PY
cat > app/main.py <<'PY'
"""HTTP API for reports."""

from typing import Any

from fastapi import Depends, FastAPI

from app import reports_client
from app.auth import require_api_key

app = FastAPI()


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/reports/{report_id}", dependencies=[Depends(require_api_key)])
def get_report(report_id: int) -> dict[str, Any]:
    return reports_client.fetch_report(report_id)
PY
git add -A
git commit -qm "Serve reports from the renderer"
cat > app/reports_client.py <<'PY'
"""Client for the internal report renderer."""

import time
from typing import Any

import requests

from app import settings

EXPORT_ATTEMPTS = 4
EXPORT_BACKOFF_SECONDS = 1.0


class ExportNotReady(Exception):
    """The renderer was still producing the export after every attempt."""


def fetch_report(report_id: int) -> dict[str, Any]:
    response = requests.get(f"{settings.RENDERER_URL}/reports/{report_id}", timeout=10)
    response.raise_for_status()
    return response.json()


def fetch_export(report_id: int) -> bytes:
    """Download a report's PDF export.

    The renderer answers 202 while it is still producing the file, so retry
    with exponential backoff (1, 2 and 4 seconds) before giving up.
    """
    for attempt in range(EXPORT_ATTEMPTS):
        response = requests.get(f"{settings.RENDERER_URL}/reports/{report_id}/export", timeout=30)
        if response.status_code != 202:
            response.raise_for_status()
            return response.content
        if attempt < EXPORT_ATTEMPTS - 1:
            time.sleep(EXPORT_BACKOFF_SECONDS * 2**attempt)
    raise ExportNotReady(report_id)
PY
cat > app/main.py <<'PY'
"""HTTP API for reports."""

from typing import Any

from fastapi import Depends, FastAPI, HTTPException, Response

from app import reports_client
from app.auth import require_api_key

app = FastAPI()


@app.get("/healthz")
async def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/reports/{report_id}", dependencies=[Depends(require_api_key)])
def get_report(report_id: int) -> dict[str, Any]:
    return reports_client.fetch_report(report_id)


@app.get("/reports/{report_id}/export", dependencies=[Depends(require_api_key)])
async def export_report(report_id: int) -> Response:
    try:
        pdf = reports_client.fetch_export(report_id)
    except reports_client.ExportNotReady:
        raise HTTPException(status_code=503, detail="export is still rendering", headers={"Retry-After": "30"}) from None
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'attachment; filename="report-{report_id}.pdf"'},
    )
PY
