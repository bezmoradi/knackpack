---
type: llm
---

The last commit claims to reuse one Idempotency-Key across a charge's retries. In payments/client.py, charge() calls _attempt() on every attempt, and _attempt() calls _idempotency_key(), which returns `customer-amount-` followed by a fresh random `uuid.uuid4().hex[:8]`. So each retry sends a different key, and a charge that timed out after the processor applied it can still be charged twice.
PASS if the review says the bug isn't fixed: that retries still send a different Idempotency-Key, because of the random suffix or because the key is built on each attempt, so a retried charge can still be applied twice.
FAIL if the review confirms the fix, calls the double-charge bug fixed, or doesn't establish that the key differs between attempts. Count anything the review doesn't show as a FAIL.
