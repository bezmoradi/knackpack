---
description: The built-in /simplify on the change whose tests assert that Save checks permission before writing, which a decision record requires. A baseline for the slop reviewer, showing whether /simplify keeps the call-order tests.
expected_outcome: files/service_test.go still asserts that CanWrite comes before Put.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify files/service.go files/service_test.go
