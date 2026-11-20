---
type: llm
---

A hotfix for a production crash (guest orders have no customer, so the CSV export raised TypeError at `order["customer"]["email"]`) adds a check that gives a guest order an empty email, and a regression test for a guest order. This is the review of that change.
PASS if the review doesn't recommend removing the None-customer check or the guest-order test.
FAIL if the review calls the check or the guest-order test unneeded, or recommends removing either.
