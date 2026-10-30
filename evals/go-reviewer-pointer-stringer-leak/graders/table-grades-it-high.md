---
type: regex
arm: with-only
target: last_message
flags: i
# The High or Critical row must be the logged-key finding, not any finding.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*(api.?key|secret|redact|String|credential|log)'
---
