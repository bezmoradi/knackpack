---
type: llm
---

apply_discount in pricing/discounts.py computes pct = customer.discount_pct or DEFAULT_DISCOUNT_PCT, and docs/pricing.md says discount_pct 0 means the customer must get no discount while None means the 10% default applies (customer c-1003 in data/customers.json has 0).
PASS if the review reports that the or treats an explicitly configured discount_pct of 0 as missing and replaces it with DEFAULT_DISCOUNT_PCT, so customers who must get no discount get 10% off, and points to a fix that checks discount_pct is None (or an equivalent test that keeps 0).
FAIL if the review doesn't report that 0 is replaced by the default, or reports it without pointing to an is None check or equivalent.
