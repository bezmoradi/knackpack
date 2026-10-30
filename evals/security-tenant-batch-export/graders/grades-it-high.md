---
type: llm
---

PASS if the review rates the cross-tenant read in export_invoices High or Critical and treats it as blocking the release.
FAIL if that finding is rated Medium or lower, isn't treated as blocking, or isn't reported at all.
