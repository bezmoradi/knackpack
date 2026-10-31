---
description: An uncommitted change to the charts/api Helm chart adds serviceAccount.automount, set to true in values.yaml, renders the pods' automountServiceAccountToken from it directly, and sets it to false in a new values-prod.yaml, as the README requires for production. The render with the production values shows false, and the Kubernetes reviewer doesn't report the token as still mounted or the false as overridden.
expected_outcome: The review doesn't report that production still mounts the token or that the false from values-prod.yaml is overridden, and rates nothing about it High, Critical or blocking; with the plugin, the Kubernetes reviewer ran.
tags: [kubernetes, kubernetes-reviewer, kubernetes-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Helm chart changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
