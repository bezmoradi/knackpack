#!/bin/bash
# An MCP server over streamable HTTP that lets assistants list and read a
# person's documents through a downstream documents API, committed, plus an
# uncommitted change that adds a tool for deleting documents.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p server docs
cat > requirements.txt <<'TXT'
mcp==1.30.0
httpx==0.28.1
TXT
cat > docs/documents-api.md <<'MD'
# Documents API

The documents service stores the files people upload and decides who may see
them. This MCP server is one of its clients. Base URL: `DOCS_API_URL`.

## Authentication

Every request carries `Authorization: Bearer <token>`, a token from the
identity provider with audience `documents-api`. Two kinds are accepted:

- **User tokens** act for one person, the token's `sub`, and the API applies
  that person's permissions: they see only the documents they own or that were
  shared with them. A service acting for a signed-in user gets one by
  exchanging the user's token at the identity provider (RFC 8693).
- **Service tokens** are issued to a service for its own work. They aren't
  tied to a user and can reach every document.

## Endpoints

| Method and path | Accepts | Returns |
|---|---|---|
| `GET /documents` | user tokens | the documents the user may access: `id`, `title`, `owner`, `updated_at` |
| `GET /documents/{id}` | user tokens | the document with its `content`; 404 if the user may not access it |
| `DELETE /documents/{id}` | service tokens only | 204; 403 for a user token |

Deletion is permanent; there is no trash.
MD
cat > server/__init__.py <<'PY'
PY
cat > server/__main__.py <<'PY'
import logging

from .main import mcp

logging.basicConfig(level=logging.INFO)
mcp.run(transport="streamable-http")
PY
cat > server/settings.py <<'PY'
"""Configuration, read from the environment at startup."""

import os

IDP_ISSUER = os.environ["IDP_ISSUER"]
IDP_INTROSPECTION_URL = os.environ.get("IDP_INTROSPECTION_URL", f"{IDP_ISSUER}/oauth2/introspect")
IDP_TOKEN_URL = os.environ.get("IDP_TOKEN_URL", f"{IDP_ISSUER}/oauth2/token")

# This server's public URL: the audience its access tokens must carry.
MCP_RESOURCE_URL = os.environ["MCP_RESOURCE_URL"]

# This server's own client credentials at the identity provider.
CLIENT_ID = os.environ["MCP_CLIENT_ID"]
CLIENT_SECRET = os.environ["MCP_CLIENT_SECRET"]

DOCS_API_URL = os.environ["DOCS_API_URL"]
DOCS_API_AUDIENCE = os.environ.get("DOCS_API_AUDIENCE", "documents-api")
PY
cat > server/auth.py <<'PY'
"""Checks the tokens MCP clients send, and gets documents API tokens for them."""

import httpx

from mcp.server.auth.provider import AccessToken, TokenVerifier

from . import settings

_TIMEOUT = httpx.Timeout(5.0)


class IntrospectionVerifier(TokenVerifier):
    """Asks the identity provider whether a token is active and issued for this server (RFC 7662)."""

    async def verify_token(self, token: str) -> AccessToken | None:
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
                resp = await client.post(
                    settings.IDP_INTROSPECTION_URL,
                    data={"token": token, "token_type_hint": "access_token"},
                    auth=(settings.CLIENT_ID, settings.CLIENT_SECRET),
                )
            resp.raise_for_status()
            info = resp.json()
        except (httpx.HTTPError, ValueError):
            return None
        if info.get("active") is not True:
            return None
        aud = info.get("aud")
        if settings.MCP_RESOURCE_URL not in (aud if isinstance(aud, list) else [aud]):
            return None
        return AccessToken(
            token=token,
            client_id=info["client_id"],
            scopes=str(info.get("scope", "")).split(),
            expires_at=info.get("exp"),
        )


async def documents_token_for(user_token: str) -> str:
    """Exchanges the caller's token for a documents API token that acts for the same user (RFC 8693)."""
    async with httpx.AsyncClient(timeout=_TIMEOUT) as client:
        resp = await client.post(
            settings.IDP_TOKEN_URL,
            data={
                "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
                "subject_token": user_token,
                "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
                "audience": settings.DOCS_API_AUDIENCE,
            },
            auth=(settings.CLIENT_ID, settings.CLIENT_SECRET),
        )
    resp.raise_for_status()
    return resp.json()["access_token"]
PY
cat > server/docs_client.py <<'PY'
"""A small client for the documents API (docs/documents-api.md)."""

import re

import httpx

from . import settings

_DOC_ID = re.compile(r"[A-Za-z0-9_-]{1,64}")


class DocumentsAPIError(Exception):
    pass


class DocsClient:
    def __init__(self, base_url: str = settings.DOCS_API_URL, timeout: float = 10.0):
        self._base_url = base_url.rstrip("/")
        self._timeout = timeout

    @staticmethod
    def _doc_path(doc_id: str) -> str:
        if not _DOC_ID.fullmatch(doc_id):
            raise ValueError("invalid document ID")
        return f"/documents/{doc_id}"

    async def _request(self, method: str, path: str, token: str) -> httpx.Response:
        async with httpx.AsyncClient(base_url=self._base_url, timeout=self._timeout) as client:
            resp = await client.request(method, path, headers={"Authorization": f"Bearer {token}"})
        if resp.status_code == 404:
            raise DocumentsAPIError("document not found")
        if resp.status_code >= 400:
            raise DocumentsAPIError(f"documents API returned {resp.status_code}")
        return resp

    async def list_documents(self, token: str) -> list[dict]:
        return (await self._request("GET", "/documents", token)).json()

    async def get_document(self, token: str, doc_id: str) -> dict:
        return (await self._request("GET", self._doc_path(doc_id), token)).json()
PY
cat > server/main.py <<'PY'
"""MCP server that gives assistants access to a person's documents."""

import logging

from pydantic import AnyHttpUrl

from mcp.server.auth.middleware.auth_context import get_access_token
from mcp.server.auth.provider import AccessToken
from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP

from . import settings
from .auth import IntrospectionVerifier, documents_token_for
from .docs_client import DocsClient

log = logging.getLogger("docs_mcp")

mcp = FastMCP(
    "docs",
    token_verifier=IntrospectionVerifier(),
    auth=AuthSettings(
        issuer_url=AnyHttpUrl(settings.IDP_ISSUER),
        resource_server_url=AnyHttpUrl(settings.MCP_RESOURCE_URL),
        required_scopes=["documents:read"],
        # IntrospectionVerifier checks the audience itself.
        validate_token_resource=False,
    ),
)
docs = DocsClient()


def _caller() -> AccessToken:
    access = get_access_token()
    if access is None:
        raise PermissionError("not authenticated")
    return access


@mcp.tool()
async def list_documents() -> list[dict]:
    """List the documents you can access."""
    access = _caller()
    return await docs.list_documents(await documents_token_for(access.token))


@mcp.tool()
async def read_document(doc_id: str) -> dict:
    """Read one document by its ID."""
    access = _caller()
    log.info("read_document doc_id=%s client_id=%s", doc_id, access.client_id)
    return await docs.get_document(await documents_token_for(access.token), doc_id)
PY
git add -A
git commit -qm "Add documents MCP server with list and read tools"
cat >> server/settings.py <<'PY'

# Service token for the documents API, which accepts DELETE only from services.
ADMIN_API_TOKEN = os.environ["ADMIN_API_TOKEN"]
PY
cat >> server/docs_client.py <<'PY'

    async def delete_document(self, token: str, doc_id: str) -> None:
        await self._request("DELETE", self._doc_path(doc_id), token)
PY
cat >> server/main.py <<'PY'


@mcp.tool()
async def delete_document(doc_id: str) -> dict:
    """Delete a document permanently."""
    access = _caller()
    log.info("delete_document doc_id=%s client_id=%s", doc_id, access.client_id)
    await docs.delete_document(settings.ADMIN_API_TOKEN, doc_id)
    return {"deleted": doc_id}
PY
