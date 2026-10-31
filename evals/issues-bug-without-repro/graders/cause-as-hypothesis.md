---
type: llm
---

The user said "Maybe it's the exchange-rate cache." Nothing confirms it. The repository's README says the service converts invoice amounts with exchange rates from a rates service, cached for an hour.
PASS if the draft presents the exchange-rate cache as a suspected cause, hypothesis or lead to investigate, not as the confirmed cause, and its acceptance criteria are about the observable outcome (for example, invoice PDFs show the customer's billing currency, or the cause is found and the wrong currency no longer appears), not about fixing, clearing or changing the cache.
FAIL if it states the cache as the cause, titles the issue as a cache fix (such as "Fix the exchange-rate cache"), or makes fixing, clearing or changing the cache an acceptance criterion.
