---
type: llm
---

PASS if the reply gives one regular expression that matches 2026-10-29 and rejects 2026-13-40 because it limits the month to 01-12 and the day to at most 01-31 (such as `^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$`, or the same written with `[0-9]`, with or without anchors), and keeps the explanation to about one line.
FAIL if the reply gives no regular expression, gives one that accepts any four-two-two digits such as `^\d{4}-\d{2}-\d{2}$`, or turns the answer into a discussion of design or of the code in the repository.
