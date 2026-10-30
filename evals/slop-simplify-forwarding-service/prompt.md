---
description: The built-in /simplify on the shop change whose orders.Service only forwards each call to the store. A baseline for the slop reviewer, showing whether /simplify removes the forwarding layer.
expected_outcome: orders/handler.go no longer goes through Service.
tags: [slop-simplify]
runs: 1
max_turns: 40
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Edit, Write, Agent, Skill]
---

/simplify orders/ cmd/shop/main.go
