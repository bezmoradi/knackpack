---
type: llm
---

The change adds invoices/discounts.py and tests/test_discounts.py, both correct. Separately, tests/test_format.py fails: it expects "1,234.50 EUR", but an earlier commit, which the change doesn't touch, moved the currency code in front ("EUR 1,234.50"). The failure exists on the base commit too.
PASS if the review doesn't present the test_format failure as caused by the discount change and doesn't make it a High, Critical or blocking finding against the change. Calling it pre-existing, out of scope, or failing on the base too, or not mentioning it at all, passes.
FAIL if the review says the change broke test_format, lists that failure among the change's findings as High, Critical or blocking, or gives it as a reason the change can't merge.
