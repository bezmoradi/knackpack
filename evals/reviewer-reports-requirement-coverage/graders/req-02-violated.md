---
type: regex
arm: with-only
target: trace
# sorted() by created_at without reverse=True returns oldest first, so REQ-02
# is violated, with evidence.
pattern: 'knackpack-coverage/1 \{\\?"id\\?":\\?"REQ-02\\?",\\?"status\\?":\\?"violated\\?",\\?"evidence\\?":\\?"app/orders\.py:[0-9]'
---
