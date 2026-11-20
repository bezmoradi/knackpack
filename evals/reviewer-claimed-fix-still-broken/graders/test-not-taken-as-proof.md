---
type: llm
---

The commit's regression test, test_retry_reuses_idempotency_key in tests/test_client.py, strips the last `-` segment from each Idempotency-Key with `rsplit("-", 1)[0]` before comparing them, so it passes even though every attempt's full key differs.
PASS if the review says the regression test doesn't show the keys are equal, for example because it compares the keys with their suffix removed, or doesn't treat the test as evidence that the bug is fixed.
FAIL if the review cites the regression test, or tests passing, as evidence that retries reuse the key or that the bug is fixed.
