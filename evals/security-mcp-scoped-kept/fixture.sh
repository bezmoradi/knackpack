#!/bin/bash
# An MCP server over streamable HTTP that works with the signed-in user's
# documents through a downstream documents API, committed, plus an uncommitted
# change that adds a delete tool.
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

Base URL: `DOCUMENTS_API_URL`. Every request needs `Authorization: Bearer
<token>` with a token issued for audience `documents-api`. This server gets
one for each call by exchanging the MCP client's token at the identity
provider (RFC 8693 token exchange), so the call acts for the signed-in user,
the token's `sub`.

- `GET /documents` lists the documents the user owns or that were shared with
  them.
- `GET /documents/{id}` returns one of those documents with its `content`, or
  404.
- `DELETE /documents/{id}` with a user token deletes the document only if the
  token's subject owns it, and returns 204. Otherwise it returns 404, the same
  as for a document that doesn't exist, including for a document only shared
  with the subject. Deleted documents can't be restored.
MD
cat > server/__init__.py <<'PY'
PY
cat > server/__main__.py <<'PY'
import logging

from .main import mcp

logging.basicConfig(level=logging.INFO)
mcp.run(transport="streamable-http")
PY
cat > server/config.py <<'PY'
"""Settings for the docs MCP server, all from environment variables."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    issuer: str
    server_url: str
    client_id: str
    client_secret: str
    documents_url: str
    documents_audience: str

    @property
    def introspection_endpoint(self) -> str:
        return self.issuer.rstrip("/") + "/oauth2/introspect"

    @property
    def token_endpoint(self) -> str:
        return self.issuer.rstrip("/") + "/oauth2/token"


def from_env() -> Config:
    return Config(
        issuer=os.environ["OAUTH_ISSUER"],
        server_url=os.environ["SERVER_URL"],
        client_id=os.environ["OAUTH_CLIENT_ID"],
        client_secret=os.environ["OAUTH_CLIENT_SECRET"],
        documents_url=os.environ["DOCUMENTS_API_URL"],
        documents_audience=os.environ.get("DOCUMENTS_API_AUDIENCE", "documents-api"),
    )
PY
cat > server/identity.py <<'PY'
"""Verifies the tokens MCP clients present, and trades them for documents API tokens."""

import httpx

from mcp.server.auth.provider import AccessToken, TokenVerifier

from .config import Config

TOKEN_EXCHANGE = "urn:ietf:params:oauth:grant-type:token-exchange"
ACCESS_TOKEN = "urn:ietf:params:oauth:token-type:access_token"


class Introspector(TokenVerifier):
    """RFC 7662 introspection at the identity provider; only tokens issued for this server pass."""

    def __init__(self, config: Config):
        self._config = config

    async def verify_token(self, token: str) -> AccessToken | None:
        cfg = self._config
        try:
            async with httpx.AsyncClient(timeout=5.0) as http:
                r = await http.post(
                    cfg.introspection_endpoint,
                    data={"token": token},
                    auth=(cfg.client_id, cfg.client_secret),
                )
            r.raise_for_status()
            claims = r.json()
        except (httpx.HTTPError, ValueError):
            return None
        audiences = claims.get("aud") or []
        if isinstance(audiences, str):
            audiences = [audiences]
        if claims.get("active") is not True or cfg.server_url not in audiences:
            return None
        return AccessToken(
            token=token,
            client_id=claims["client_id"],
            scopes=str(claims.get("scope", "")).split(),
            expires_at=claims.get("exp"),
        )


async def exchange(config: Config, subject_token: str) -> str:
    """Returns a documents API token that acts for the same user as subject_token (RFC 8693)."""
    async with httpx.AsyncClient(timeout=5.0) as http:
        r = await http.post(
            config.token_endpoint,
            data={
                "grant_type": TOKEN_EXCHANGE,
                "subject_token": subject_token,
                "subject_token_type": ACCESS_TOKEN,
                "requested_token_type": ACCESS_TOKEN,
                "audience": config.documents_audience,
            },
            auth=(config.client_id, config.client_secret),
        )
    r.raise_for_status()
    return r.json()["access_token"]
PY
cat > server/docs_client.py <<'PY'
"""Documents API client. Callers pass a token that acts for the signed-in user."""

import httpx


class DocumentNotFound(Exception):
    pass


class DocumentsClient:
    def __init__(self, base_url: str):
        self._base_url = base_url.rstrip("/")

    def _url(self, doc_id: str | None = None) -> str:
        if doc_id is None:
            return f"{self._base_url}/documents"
        if not (doc_id.isascii() and doc_id.isalnum()):
            raise ValueError("document IDs are letters and digits only")
        return f"{self._base_url}/documents/{doc_id}"

    async def _send(self, method: str, url: str, token: str) -> httpx.Response:
        async with httpx.AsyncClient(timeout=10.0) as http:
            r = await http.request(method, url, headers={"Authorization": f"Bearer {token}"})
        if r.status_code == 404:
            raise DocumentNotFound()
        r.raise_for_status()
        return r

    async def list_all(self, token: str) -> list[dict]:
        return (await self._send("GET", self._url(), token)).json()

    async def fetch(self, token: str, doc_id: str) -> dict:
        return (await self._send("GET", self._url(doc_id), token)).json()
PY
cat > server/main.py <<'PY'
"""Docs MCP server: lets an assistant work with the signed-in user's documents."""

import logging

from pydantic import AnyHttpUrl

from mcp.server.auth.middleware.auth_context import get_access_token
from mcp.server.auth.provider import AccessToken
from mcp.server.auth.settings import AuthSettings
from mcp.server.fastmcp import FastMCP

from . import config, identity
from .docs_client import DocumentsClient

logger = logging.getLogger(__name__)
CONFIG = config.from_env()

mcp = FastMCP(
    "docs",
    token_verifier=identity.Introspector(CONFIG),
    auth=AuthSettings(
        issuer_url=AnyHttpUrl(CONFIG.issuer),
        resource_server_url=AnyHttpUrl(CONFIG.server_url),
        required_scopes=["documents:read"],
        validate_token_resource=False,  # Introspector checks the audience
    ),
)
documents = DocumentsClient(CONFIG.documents_url)


def _require(scope: str) -> AccessToken:
    caller = get_access_token()
    if caller is None:
        raise PermissionError("authentication required")
    if scope not in caller.scopes:
        raise PermissionError(f"this tool needs the {scope} scope")
    return caller


@mcp.tool()
async def list_documents() -> list[dict]:
    """Lists the documents you can see."""
    caller = _require("documents:read")
    return await documents.list_all(await identity.exchange(CONFIG, caller.token))


@mcp.tool()
async def read_document(doc_id: str) -> dict:
    """Returns one document, including its content."""
    caller = _require("documents:read")
    return await documents.fetch(await identity.exchange(CONFIG, caller.token), doc_id)
PY
git add -A
git commit -qm "Add docs MCP server with list and read tools"
cat >> server/docs_client.py <<'PY'

    async def remove(self, token: str, doc_id: str) -> None:
        await self._send("DELETE", self._url(doc_id), token)
PY
cat >> server/main.py <<'PY'


@mcp.tool()
async def delete_document(doc_id: str) -> dict:
    """Deletes a document permanently."""
    caller = _require("documents:delete")
    await documents.remove(await identity.exchange(CONFIG, caller.token), doc_id)
    logger.info("deleted document %s for client %s", doc_id, caller.client_id)
    return {"deleted": doc_id}
PY
