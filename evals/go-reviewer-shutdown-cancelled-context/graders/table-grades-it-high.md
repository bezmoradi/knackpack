---
type: regex
arm: with-only
target: last_message
flags: i
# The High or Critical row must be the shutdown finding, not any finding.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*(Shutdown|cancel|context|drain|in-flight)'
---
