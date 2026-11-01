---
description: The user asks for a review of an uncommitted change to one Go file. That's a request for one review of Go code, so the Go reviewer runs and the Orchestrate review skill, which starts every reviewer that applies and costs as much as all of them together, doesn't start.
expected_outcome: The Orchestrate review skill never loads, and the knackpack Go reviewer runs.
tags: [trigger]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent, Skill]
---

Review my uncommitted change to handlers.go. I can't open files on this machine, so put the review in your reply.
