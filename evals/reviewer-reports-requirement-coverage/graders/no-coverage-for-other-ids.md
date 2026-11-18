---
type: regex
arm: with-only
target: trace
match: not_contains
# Only REQ-01 and REQ-02 were given, so no coverage line names another ID.
pattern: 'knackpack-coverage/1 \{\\?"id\\?":\\?"(REQ-0[^12]|REQ-[1-9]|[A-QS-Z])'
---
