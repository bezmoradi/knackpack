---
type: regex
arm: with-only
target: last_message
flags: i
# The High or Critical row must be the lock finding, not any finding.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*(RLock|read lock|deadlock|RWMutex|Len|Summary|lock)'
---
