---
type: regex
arm: with-only
target: last_message
match: not_contains
# The skill numbers its work packages PLAN-01, PLAN-02 and so on, so a reply
# that lays out packages for the blocked brief anyway fails this.
pattern: '\bPLAN-\d+\b'
---
