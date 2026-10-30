---
type: regex
arm: with-only
target: last_message
# The verdict itself, not the phrase anywhere in the report.
pattern: '(?:[Vv]erdict|[Rr]ecommendation|[Dd]ecision)\W[^\n.]{0,60}READY FOR REQUIRED HUMAN REVIEW'
---
