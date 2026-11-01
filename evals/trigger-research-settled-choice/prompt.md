---
description: The user has already decided that a Go CLI's timeout flag should take a duration such as 30s instead of a number of seconds, and asks for the change. The decision is made, so the Research skill doesn't start, and main.go gets a duration flag with the same 30-second default.
expected_outcome: The Research skill never loads, and main.go declares the timeout with flag.Duration and a default of 30 seconds.
tags: [trigger]
runs: 1
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Skill]
---

We've already decided this one: the -timeout flag should take a duration like 30s or 2m instead of a number of seconds. Make the change in main.go and keep the default at 30 seconds.
