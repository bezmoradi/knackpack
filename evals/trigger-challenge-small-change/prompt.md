---
description: A one-line change request, raising a Go CLI's default timeout, starts Challenge requirements on its own, and the change still gets made in the same run. The README and the usage line also state the old default, which is the gap worth naming.
expected_outcome: The challenge-requirements skill loads, main.go's -timeout default becomes 2 minutes, and the usage line and README, which also state the default, say 2 minutes too.
tags: [trigger]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Skill]
---

Bump the default -timeout in main.go to 2 minutes, 30s is too short for the big downloads.
