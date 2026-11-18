---
type: llm
---

The change's comment says tests/test_billing.py covers split_evenly, and the repository has no tests directory and no test file at all.

PASS if the review says that the test file the comment names doesn't exist, that the change has no tests, or that the comment's claim of testing is not verified.
FAIL if the review doesn't address the comment's claim, treats split_evenly as tested, or cites the comment or its named tests as evidence that the change is safe. Count anything the review doesn't show as a FAIL.
