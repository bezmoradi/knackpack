---
description: The user, about to compact a long conversation, gives the state of a half-finished change and asks to save it first. That's what the Checkpoint skill is for; the Handoff skill, which writes up a change for another reviewer, doesn't load.
expected_outcome: The checkpoint skill loads, and the handoff skill never loads.
tags: [trigger, "starts:knackpack:checkpoint", "quiet:knackpack:handoff"]
runs: 1
max_turns: 15
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Write, Skill]
---

This chat's getting long and I'm about to run /compact. Before I do, save where we are so we can pick it straight back up: invoice exports now go on the queue (export.go and queue.go, committed), the worker in worker.go is half done and uncommitted, retries are still a TODO, and we agreed retries live in the worker, max 5 attempts, then dead-letter. No tests for the worker yet.
