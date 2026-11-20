---
description: The task was one flag, -dry-run, for a Go backup-pruning CLI. The uncommitted change adds it, and also renames internal/store to internal/archive, splits its file into three, renames every exported function, type and field and their callers, and rewrites the README, so the flag is a few lines of a large diff. The slop reviewer reports the rename and split as work outside the task that hides the flag from review, and keeps the flag.
expected_outcome: The review reports the package rename, file split and renamed identifiers as outside the -dry-run task, big enough to hide the real change, and suggests a separate change for them; it doesn't recommend removing the -dry-run flag or its test; with the plugin, the slop reviewer ran.
tags: [consistency, mode:scope-discipline, "starts:knackpack:slop-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

Ops asked for a -dry-run flag on `backupctl prune` so they can see what it would delete before it deletes anything. It's done and uncommitted. Can you check it for slop before I open the PR, anything in there we don't need?

I can't open files on this machine, so put the full review in your reply, exactly as written.
