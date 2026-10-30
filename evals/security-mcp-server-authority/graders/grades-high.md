---
type: llm
---

PASS if the review rates the finding that delete_document deletes with the server's admin token, letting callers delete other users' documents, as High or Critical.
FAIL if it rates that finding Medium or lower, gives it no severity, or doesn't report it.
