---
type: llm
---

PASS if the reply proposes a plainer TypeScript form that keeps the three rates' behavior, such as a Record mapping ShippingKind to a rate function, a function type passed to quote, or a discriminated union with an exhaustive switch, and names a concrete benefit (less code, no class instantiation for stateless rules, compile-time exhaustiveness, easier to read or test). It should describe the current code as working but heavier than needed, and may say when classes would be the right choice.
FAIL if the reply says the hierarchy should stay as it is, proposes adding more structure, or grades the current code a High or Critical defect.
