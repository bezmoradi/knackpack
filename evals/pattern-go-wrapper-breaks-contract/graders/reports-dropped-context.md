---
type: llm
---

PASS if the reply reports that logging.Store.Get replaces the caller's context with context.Background(), so the caller's cancellation and deadline no longer reach the wrapped store, and treats that as a break of the Store contract.
FAIL if the reply misses the replaced context or accepts the code comment's justification ("logging must never be affected by a caller's short deadline") without noting that the inner Get, not only the logging, lost the deadline.
