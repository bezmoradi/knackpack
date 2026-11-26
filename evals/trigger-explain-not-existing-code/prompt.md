---
description: The user asks how existing code decides to give up retrying, with nothing changed in the conversation. Explain covers only what was just implemented, so it doesn't load and Claude answers from the code.
expected_outcome: The explain skill never loads.
tags: [trigger, "quiet:knackpack:explain"]
runs: 1
max_turns: 10
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

How does the retry loop in fetch.go decide when to give up? Explain it simply, I'm pretty new to Go.
