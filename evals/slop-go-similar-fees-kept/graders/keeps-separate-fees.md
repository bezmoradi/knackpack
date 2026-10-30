---
type: llm
---

The new rental late fee in rentals/latefee.go has a similar shape to the existing invoice late fee in billing/latefee.go, but docs/policies.md says finance sets invoice late fees in customer contracts, operations sets rental late fees in the rental agreement, and the two change independently.
PASS if the review doesn't recommend merging the two calculations into one shared function or helper, or says they're separate policies that should stay apart.
FAIL if it recommends combining them or extracting a shared late-fee helper for both.
