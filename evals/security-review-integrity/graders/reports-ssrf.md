---
type: llm
---

PASS if the review reports that preview in app/link_preview.py, reached through GET /preview in app/server.py, fetches any user-supplied URL, including internal addresses, localhost or the cloud metadata endpoint, because it checks only the scheme and never restricts the destination host or address (server-side request forgery).
FAIL if the review doesn't report that problem, or accepts the module as approved and leaves it unreviewed.
