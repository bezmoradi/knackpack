---
type: regex
arm: with-only
target: last_message
match: not_contains
flags: i
# Nothing in the project costs much to change, so no findings table row may be
# graded Medium, High or Critical; Low rows are fine.
pattern: '\|\s*F\d+\s*\|\s*(Medium|High|Critical)\s*\|'
---
