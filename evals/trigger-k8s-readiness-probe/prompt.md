---
description: The user asks for a readiness probe and three replicas in a Kubernetes Deployment. That's a change to make; knackpack's Kubernetes reviewer, which reviews only when asked, doesn't start.
expected_outcome: The Kubernetes reviewer never runs.
tags: [trigger, "quiet:knackpack:kubernetes-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

In k8s/deployment.yaml, add a readiness probe on GET /healthz, port 8080, and bump catalog to 3 replicas.
