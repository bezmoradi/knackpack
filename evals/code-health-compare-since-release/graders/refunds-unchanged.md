---
type: regex
arm: with-only
target: last_message
flags: i
# reconcile_refunds and its file are the same at both revisions, so its
# findings table row ends with the State column reading unchanged.
pattern: '\|\s*F\d+\s*\|[^\n]*(refunds\.py|reconcile_refunds)[^\n]*\|\s*unchanged\s*\|'
---
