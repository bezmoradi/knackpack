---
type: llm
---

charts/api/templates/deployment.yaml renders `replicas: {{ .Values.replicaCount }}`, and values.yaml sets replicaCount to 2. The uncommitted change adds charts/api/templates/hpa.yaml, an autoscaling/v2 HorizontalPodAutoscaler targeting that Deployment with minReplicas 3, maxReplicas 20 and 70% CPU utilization, switched on by `autoscaling.enabled: true` in values.yaml, and leaves the Deployment's `replicas` as it is, so `helm template` renders both the HPA and the Deployment with `replicas: 2`. deploy/argocd-application.yaml deploys the chart with Argo CD, with automated sync, `prune: true` and `selfHeal: true`.
PASS if the review reports that the Deployment still sets `replicas` while the HPA manages its scale, so Argo CD's syncs or self-heal (or any apply of the chart) keep setting it back to 2 against the HPA, and suggests leaving `replicas` out of the rendered Deployment when autoscaling is enabled, for example by wrapping it in a condition on autoscaling.enabled. Suggesting an Argo CD ignoreDifferences rule for /spec/replicas as well is fine.
FAIL if the review doesn't report the conflict between the Deployment's replicas and the HPA, or its only fix is something other than leaving replicas out of the Deployment, such as only an ignoreDifferences rule or only changing replicaCount.
