---
type: llm
---

The change adds the same free-shipping rule twice, as `>= 5000` checks in cart/preview.go and checkout/checkout.go, while the pricing package already holds the shipping charge both files use.
PASS if the review reports that the free-shipping rule or its threshold is duplicated across the two files and recommends one shared definition, such as a function or constant in pricing.
FAIL if it doesn't report the duplication.
