---
type: regex
arm: with-only
target: last_message
flags: i
# The High or Critical row must be the path finding, not any finding.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*(HasPrefix|prefix|travers|path|folder|director|organi[sz]ation|tenant)'
---
