---
description: An uncommitted change to the charts/api Helm chart renders the pods' automountServiceAccountToken from serviceAccount.automount piped through default true, with no default in values.yaml, and sets automount to false in a new values-prod.yaml, while the README says production pods must not mount a Kubernetes API token. Helm's default treats false as empty, so production still renders true, and the Kubernetes reviewer reports it with a presence check or a values.yaml default as the fix.
expected_outcome: The review reports that default true turns the explicit false from values-prod.yaml into true, so production pods still mount the token, and suggests hasKey or another presence check, or a default in values.yaml; with the plugin, the Kubernetes reviewer ran.
tags: [kubernetes, kubernetes-reviewer, kubernetes-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Helm chart changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
