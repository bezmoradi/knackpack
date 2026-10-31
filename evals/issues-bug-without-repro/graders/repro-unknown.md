---
type: llm
---

The user said that some customers report their invoice PDFs sometimes show the wrong currency, that the team can't reproduce it yet, and that the exchange-rate cache might be the cause. They gave no reproduction steps, customers, currencies, invoice numbers, dates or frequency.
PASS if the draft says the reproduction steps are unknown or not yet found (for example "Steps to reproduce: unknown; not reproduced yet"), and presents no invented steps, specific currencies, customers, invoice numbers, dates or frequencies as observed facts. Listing what to collect next (such as affected invoice IDs, the currency shown and the one expected, when the invoices were generated) as open questions or evidence to gather is fine.
FAIL if it writes reproduction steps the user didn't give, or presents invented specifics (such as "EUR invoices show USD" or "happens right after the rates refresh") as observed facts.
