---
type: regex
arm: with-only
target: last_message
flags: i
# The High or Critical row must be the key-change finding, not any finding.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*(json|key|wire|CustomerI[dD]|InvoiceI[dD]|ledger)'
---
