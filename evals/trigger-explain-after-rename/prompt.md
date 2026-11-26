---
description: The user asks for a small change and then a plain-English explanation of what was done, for a junior developer. Once the change is made, explaining what was just implemented starts the Explain skill; the Handoff skill, a write-up for a reviewer, doesn't load.
expected_outcome: The explain skill loads, and the handoff skill never loads.
tags: [trigger, "starts:knackpack:explain", "quiet:knackpack:handoff"]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Skill]
---

Rename the -timeout flag to -deadline everywhere it shows up. Once that's done, explain what you changed for Priya, she joined last week and hasn't seen this code, so keep it plain.
