---
description: The user wants a write-up of their branch to give another coding agent, which will do the principal review. That's the Handoff skill; the Checkpoint skill, which saves state before a compaction, doesn't load, and knackpack's adversarial reviewer doesn't start, since the review happens elsewhere.
expected_outcome: The handoff skill loads, the checkpoint skill never loads, and the adversarial reviewer never runs.
tags: [trigger, "starts:knackpack:handoff", "quiet:knackpack:checkpoint", "quiet:knackpack:adversarial-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Agent, Skill]
---

I'm giving the rate-limit branch to another agent to do the proper review, not you. Can you write it up for them? What changed, why, and where they should look hardest.
