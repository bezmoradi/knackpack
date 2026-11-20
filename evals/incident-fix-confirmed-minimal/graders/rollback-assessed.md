---
type: llm
---

Claude fixed a crash in a CSV export so that guest orders get an empty email. This is Claude's final reply.
PASS if the reply assesses rollback: whether reverting the change is clean, and whether it touches data, a format consumers read, or another side effect that a revert would have to account for.
FAIL if the reply says nothing about rolling the change back, or only asserts it's safe without saying what it looked at.
