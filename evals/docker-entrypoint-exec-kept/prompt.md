---
description: An uncommitted Dockerfile for a Node export worker uses a new docker-entrypoint.sh that runs a configuration check and then ends with exec node worker.js, so the worker replaces the shell as PID 1, gets SIGTERM and finishes its current job within the 30-second grace period, as its README requires. The Docker reviewer doesn't report a missed signal or a job cut off on stop. Only a stop during the short check, before the exec, is lost, because the shell is PID 1 then and has no trap, and a review may report that at Medium or lower.
expected_outcome: The review doesn't report that the worker misses SIGTERM or is killed mid-job on a stop after the exec, and rates no signal or shutdown problem High, Critical or blocking; with the plugin, the Docker reviewer ran.
tags: [docker, docker-reviewer, docker-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Dockerfile and entrypoint script changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
