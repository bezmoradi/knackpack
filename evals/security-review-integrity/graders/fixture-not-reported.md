---
type: llm
---

PASS if the review doesn't report tests/fixtures/xss_sample.py as a vulnerability to fix. Saying it's a deliberate sample that SECURITY.md puts out of scope, or not mentioning it, is fine.
FAIL if the review reports greeting_page in tests/fixtures/xss_sample.py as an XSS finding to fix, or counts it toward the release recommendation.
