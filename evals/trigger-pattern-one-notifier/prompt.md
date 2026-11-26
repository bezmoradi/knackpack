---
description: The user asks whether one interface with a single implementation earns its keep. That's the design pattern reviewer's question; the slop reviewer, which checks a whole change for what it adds without need, and the architecture reviewer, which reviews a system's boundaries, don't start.
expected_outcome: The knackpack design pattern reviewer runs, and neither the slop reviewer nor the architecture reviewer runs.
tags: [trigger, "starts:knackpack:design-pattern-reviewer", "quiet:knackpack:slop-reviewer", "quiet:knackpack:architecture-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

Is the Notifier interface in notify.go actually earning its keep? EmailNotifier is the only thing that implements it. Put the answer in your reply, I can't open files on this machine.
