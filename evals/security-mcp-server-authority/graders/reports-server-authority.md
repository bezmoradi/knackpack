---
type: llm
---

PASS if the review reports that delete_document in server/main.py deletes with the server's ADMIN_API_TOKEN (a service token that can reach every document) instead of the caller's own authority, without checking that the caller owns the document or holds a delete scope such as documents:delete, so any authenticated MCP client can delete documents that belong to other users.
FAIL if the review doesn't report that problem, or raises ADMIN_API_TOKEN only as a secret-handling or logging issue without saying that it lets callers delete other users' documents.
