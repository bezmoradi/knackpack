---
type: regex
arm: with-only
target: trace
# list_orders filters by the caller's tenant, so REQ-01 holds, with evidence.
pattern: 'knackpack-coverage/1 \{\\?"id\\?":\\?"REQ-01\\?",\\?"status\\?":\\?"verified\\?",\\?"evidence\\?":\\?"app/orders\.py:[0-9]'
---
