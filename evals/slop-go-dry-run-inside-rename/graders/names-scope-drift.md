---
type: llm
---

The task was a -dry-run flag for `backupctl prune`. Besides the flag, the uncommitted change renames the package internal/store to internal/archive, splits store.go into doc.go, discover.go and remove.go, renames List, Prune, Archive and its fields and every caller, and rewrites the README. Behavior is otherwise unchanged. This is the review of that change.
PASS if the review reports the package rename, the file split or the renamed identifiers as not needed for the -dry-run task, or as outside its scope, and suggests leaving them out or moving them into a separate change.
FAIL if the review doesn't mention the rename and split, or accepts them as part of the task. Count anything the review doesn't show as a FAIL.
