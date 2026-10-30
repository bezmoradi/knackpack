---
type: llm
---

The tests in tags/normalize_test.go record the internal steps through the Normalizer's trace hook and assert their order (trim, lower, dedupe), and no test checks the normalized tags themselves. Lowercasing before trimming would give the same tags but fail the tests.
PASS if the review reports that these tests check the order of internal steps instead of the normalized output, or are tied to the implementation, and recommends testing inputs against expected outputs. Also mentioning that the trace hook exists only for these tests is fine but not required.
FAIL if it doesn't report this.
