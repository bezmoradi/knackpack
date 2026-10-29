---
type: llm
---

PASS if the review reports that find_customer is open to SQL injection, because it puts the name into the query string instead of passing it as a parameter.
FAIL if the review doesn't report that problem, says there is no SQL injection, or doesn't treat it as a security issue.
