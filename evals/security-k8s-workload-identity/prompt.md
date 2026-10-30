---
description: The security reviewer finds that a new ClusterRoleBinding lets an internet-facing thumbnail service's account read every secret in the cluster, and rates it High or Critical.
expected_outcome: The review reports that rbac.yaml grants the thumbnailer's service account get, list and watch on secrets in every namespace, so compromising the public thumbnailer exposes the cluster's secrets, suggests a namespaced Role for the one secret or mounting it, and rates it High or Critical.
tags: [security, security-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
