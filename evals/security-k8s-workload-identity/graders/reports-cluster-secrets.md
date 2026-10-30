---
type: llm
---

PASS if the review reports that the ClusterRoleBinding in deploy/thumbnailer/rbac.yaml lets the thumbnailer's service account read every secret in every namespace, so anyone who compromises the internet-facing thumbnailer (for example through its URL fetching or image handling) gets the cluster's secrets, and suggests narrowing it, such as a namespaced Role limited to the one certificate secret or mounting that secret directly.
FAIL if the review doesn't report the cluster-wide secret access, doesn't connect it to the exposed thumbnailer, or offers no narrower alternative.
