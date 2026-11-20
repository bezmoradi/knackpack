---
type: regex
arm: with-only
target: last_message
match: not_contains
flags: i
# A maintainability risk is Medium at most: no findings table row on quote.py
# may be graded High or Critical.
pattern: '\|\s*F\d+\s*\|\s*(High|Critical)\s*\|[^\n]*quote\.py'
---
