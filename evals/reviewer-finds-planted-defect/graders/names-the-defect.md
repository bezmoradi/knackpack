---
type: llm
---

PASS if the review reports that update_order_status lets a caller change an order that belongs to another tenant, because it skips the tenant or ownership check that get_order makes.
FAIL if the review doesn't report that problem, or reports it only as a style or naming issue.
