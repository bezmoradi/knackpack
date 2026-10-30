---
type: regex
arm: with-only
target: last_message
# The verdict itself, not the word anywhere in the report.
pattern: '(?:[Vv]erdict|[Rr]ecommendation|[Dd]ecision)\W[^\n.]{0,60}\bBLOCKED\b'
---
