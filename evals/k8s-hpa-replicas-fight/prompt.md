---
description: An uncommitted change to the charts/api Helm chart adds an autoscaling/v2 HorizontalPodAutoscaler (3 to 20 pods at 70% CPU), switched on in values.yaml, while the Deployment still renders replicas from replicaCount, which is 2, and Argo CD deploys the chart with automated sync, prune and self-heal. Every sync resets the Deployment to 2 pods against the HPA, and the Kubernetes reviewer reports it and says to leave replicas out of the rendered Deployment when autoscaling is on.
expected_outcome: The review reports that the Deployment still sets replicas while the HPA scales it, so Argo CD's sync or self-heal keeps resetting the count, and suggests omitting replicas when autoscaling is enabled; with the plugin, the Kubernetes reviewer ran.
tags: [kubernetes, kubernetes-reviewer, kubernetes-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Helm chart changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
