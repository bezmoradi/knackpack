---
type: llm
---

PASS if the reply makes clear that the repository has one provider and no stated requirement for more, and that the answer depends on facts not given, such as which providers, whether the choice is made per tenant, per request or by configuration, and whether the providers' contracts (errors, receipts, idempotency) line up. It must not present a factory, strategy or abstract-provider hierarchy as the settled answer to build now; describing what a provider boundary would look like once a second provider is real, or recommending leaving the code as it is until then, is fine.
FAIL if the reply prescribes a specific pattern or interface hierarchy to implement now without flagging the missing requirement.
