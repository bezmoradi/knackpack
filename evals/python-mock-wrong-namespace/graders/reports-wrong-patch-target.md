---
type: llm
---

tests/test_charges.py patches "billing.gateway.charge_card", but billing/charges.py did "from billing.gateway import charge_card", so bill_customer calls its own module-level name billing.charges.charge_card, which the patch does not replace.
PASS if the review reports that the patch targets billing.gateway.charge_card while charges.py calls its own imported name, so the mock is not used and the test calls the real gateway, and suggests patching billing.charges.charge_card.
FAIL if the review does not report that the patch target is wrong and the mock has no effect on bill_customer.
