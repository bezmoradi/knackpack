---
type: regex
arm: with-only
target: last_message
flags: i
# A findings table row graded Medium or Low whose location or title is quote.py.
pattern: '\|\s*F\d+\s*\|\s*(Medium|Low)\s*\|[^\n]*quote\.py'
---
