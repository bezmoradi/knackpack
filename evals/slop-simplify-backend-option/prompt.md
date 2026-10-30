---
description: The built-in /simplify on the catalog change whose cache adds a redis backend option that nothing selects or implements. A baseline for the slop reviewer, showing whether /simplify removes the unused option.
expected_outcome: cache/cache.go no longer mentions redis.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify cache/cache.go cmd/catalog/main.go
