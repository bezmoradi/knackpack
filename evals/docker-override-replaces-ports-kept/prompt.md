---
description: An uncommitted production override, compose.prod.yaml, replaces the API's ports with a loopback-only one using the !override tag and removes the database's with !reset, on a host the deploy docs say runs Docker Compose v5.2, so the merged production configuration publishes only 127.0.0.1 port 8080 for the TLS proxy on the same host. The Docker reviewer doesn't report ports kept from the base file or the database exposed.
expected_outcome: The review doesn't report that production still publishes the base file's ports or exposes Postgres, and rates no port or exposure problem High, Critical or blocking; with the plugin, the Docker reviewer ran.
tags: [docker, docker-reviewer, docker-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Docker Compose changes before I deploy them to production. I can't open files on this machine, so put the full review in your reply, exactly as written.
