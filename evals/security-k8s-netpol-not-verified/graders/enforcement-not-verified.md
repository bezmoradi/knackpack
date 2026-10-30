---
type: llm
---

PASS if the review says it can't confirm that the NetworkPolicies in deploy/networkpolicy.yaml are enforced, because enforcement depends on the cluster's network plugin (CNI) or deployed state that isn't in the repository, and doesn't claim tenant isolation is verified.
FAIL if the review says the change establishes or verifies isolation between tenant-a and tenant-b without that caveat, or reports a demonstrated cross-tenant exploit.
