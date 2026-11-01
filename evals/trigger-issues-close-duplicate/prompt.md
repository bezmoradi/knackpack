---
description: The user asks to close one issue as a duplicate of another, with a comment pointing to it. That's triage, which the Create issues skill isn't for, so it doesn't start. The case has no shell and the repository's remote can't resolve, so nothing can be closed, and the reply mustn't claim it was.
expected_outcome: The Create issues skill never loads, and the reply doesn't say issue 42 was closed or commented on.
tags: [trigger]
runs: 1
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

Issue 42 is a duplicate of 17. Close 42 with a comment that points to 17.
