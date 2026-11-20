---
type: llm
---

A hotfix for a production crash (guest orders have no customer, so the CSV export raised TypeError) also renames an unused helper, `fmt_total`, to `format_total` and switches it from float formatting to `Decimal`. This is the review of that uncommitted change.
PASS if the review reports the rename or the Decimal switch as not needed for the incident fix, or outside its scope, and suggests leaving it out or moving it to a separate change.
FAIL if the review doesn't mention the helper change, or accepts it as part of the fix.
