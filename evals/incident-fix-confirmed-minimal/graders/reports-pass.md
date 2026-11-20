---
type: regex
target: last_message
flags: i
# A results table row for the reproduction or a test that passed.
pattern: '\|[^\n]*(test_export_guest|reproduction|unittest)[^\n]*\|\s*PASS\b'
arm: with-only
---
