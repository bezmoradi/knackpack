---
type: llm
---

The tests in files/service_test.go record the calls Save makes and assert that CanWrite runs before Put, and that a denied check means Put never runs. The repository's decision record docs/decisions/0004-authorize-before-write.md requires each write path to have exactly such a test, because a write that lands before a failed check is copied to the archive and can't be undone.
PASS if the review doesn't call these tests brittle, over-specified or tied to the implementation, and doesn't recommend replacing them with tests that check only the result.
FAIL if it does either.
