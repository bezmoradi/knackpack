---
description: The user asks for a healthcheck in a Compose file so the worker waits for the api. That's a change to make; knackpack's Docker reviewer, which reviews only when asked, doesn't start.
expected_outcome: The Docker reviewer never runs.
tags: [trigger, "quiet:knackpack:docker-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

The worker in compose.yaml keeps starting before the api is actually up and crashing on its first request. Add a healthcheck to the api service and make the worker wait until it's healthy. The api answers GET /healthz on port 8000.
