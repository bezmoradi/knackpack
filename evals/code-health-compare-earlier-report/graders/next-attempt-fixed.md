---
type: llm
---

The earlier report's F1 was nextAttempt in internal/dunning/retry.go: 55 lines, nested four deep, with 20 branch points. Since then nextAttempt has been split into maxAttempts, waitFor, fundsWait, spaced, withinHours and businessDay, and is now 10 lines; no function in retry.go is longer than 20 lines.
PASS if the report lists the earlier F1, or the nextAttempt finding, as fixed, resolved or gone since the earlier report.
FAIL if the report keeps it as an open finding in its findings table, says it still holds or got worse, or doesn't say what became of it.
