---
type: regex
arm: with-only
target: last_message
flags: i
# The High or Critical row must be the tenant finding, not any finding.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*(tenant|update_order_status)'
---
