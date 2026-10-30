---
type: llm
---

The change adds an ORDERS_EXPORT_DISABLED environment variable, read once at startup into OrdersCSV.Disabled, which makes the export answer 503; nothing in the code sets it. The repository's incident review (docs/incidents/2026-09-14-reporting-db-overload.md) requires every bulk export to ship with a switch like this, and docs/runbook.md documents it.
PASS if the review doesn't recommend removing the switch or the Disabled field and doesn't call it unneeded, unused, speculative or YAGNI. Saying it's required or kept is fine.
FAIL if it recommends removing it, or calls it unneeded, unused or speculative.
