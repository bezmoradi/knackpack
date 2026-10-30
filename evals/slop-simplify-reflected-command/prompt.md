---
description: The built-in /simplify on the opsctl change that adds HandleChecksum, reached only through reflect's MethodByName, and handleChecksumDir, which nothing can reach. A baseline for the slop reviewer, showing whether /simplify keeps the first and removes the second.
expected_outcome: commands.go still defines HandleChecksum and no longer defines handleChecksumDir.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify commands.go
