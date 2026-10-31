---
description: An uncommitted Dockerfile for a Node export worker uses a new docker-entrypoint.sh that runs a configuration check and then starts the worker without exec, so the shell stays PID 1, never passes SIGTERM on, and the worker, whose README says a job takes up to 20 seconds and must never be cut off halfway, is killed mid-job when the 30-second grace period ends. The Docker reviewer reports it and points to exec or an equivalent fix.
expected_outcome: The review reports that the shell is PID 1 and the worker never receives SIGTERM, so it's killed mid-job on every stop or redeploy, and suggests exec node worker.js or an equivalent fix; with the plugin, the Docker reviewer ran.
tags: [docker, docker-reviewer, docker-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Dockerfile and entrypoint script changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
