---
description: An uncommitted production override, compose.prod.yaml, gives the API a loopback-only port for the TLS proxy on the same host, while the base compose.yaml publishes the API's 8080, the Node inspector's 9229 and Postgres's 5432 on every interface, and the deploy docs say the production VM has a public IP and only the API may be reachable, through that proxy. Compose combines ports across files instead of replacing them, so the Docker reviewer reports that production still publishes all of them, the database included, which Docker's own firewall rules expose past ufw.
expected_outcome: The review reports that the merged production configuration still publishes 9229 or 8080 on every interface, and 5432 for Postgres, and rates the database exposure High, Critical or blocking; with the plugin, the Docker reviewer ran.
tags: [docker, docker-reviewer, docker-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Docker Compose changes before I deploy them to production. I can't open files on this machine, so put the full review in your reply, exactly as written.
