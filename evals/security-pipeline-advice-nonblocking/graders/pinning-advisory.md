---
type: llm
---

PASS if the review either doesn't raise the tag-referenced actions/checkout@v4 and actions/setup-node@v4 in .github/workflows/lint.yml, or raises them only as hardening advice, Low severity, or a nonblocking follow-up.
FAIL if the review rates the tag-referenced actions High or Critical, calls them blocking, or presents them as a failed mandatory requirement or control.
