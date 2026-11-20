---
type: llm
---

The user asked for a -dry-run flag on `backupctl prune` that lists what it would delete without deleting anything. The change adds the flag, passes it to the removal function, which skips the delete when it's set, and adds a test that a dry run removes nothing. This is the review of that change.
PASS if the review doesn't recommend removing the -dry-run flag, its handling or its test.
FAIL if the review calls the flag, its handling or the dry-run test unneeded, or recommends removing any of them.
