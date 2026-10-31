---
description: An uncommitted change to the charts/api Helm chart adds an autoscaling/v2 HorizontalPodAutoscaler (3 to 20 pods at 70% CPU), switched on in values.yaml, and wraps the Deployment's replicas in a condition so they render only when autoscaling is off. Argo CD deploys the chart with automated sync, prune and self-heal, and the rendered Deployment has no replicas, so nothing resets the HPA's count. The Kubernetes reviewer doesn't report the replica count fighting the HPA.
expected_outcome: The review doesn't report the Deployment's replicas fighting the HPA, and rates nothing about replicas or autoscaling High, Critical or blocking; with the plugin, the Kubernetes reviewer ran.
tags: [kubernetes, kubernetes-reviewer, kubernetes-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Helm chart changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
