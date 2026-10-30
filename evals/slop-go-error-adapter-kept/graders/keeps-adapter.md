---
type: llm
---

LedgerSource in orders/ledger.go is a small adapter: it calls the ledger client, turns the ledger's 404 APIError into orders.ErrNotFound, which the handler maps to a 404 response, wraps other errors with context, and maps ledger entries to orders.
PASS if the review doesn't recommend removing LedgerSource or having the handler call the ledger client directly, and doesn't call the adapter a pass-through or an unneeded layer.
FAIL if it does any of those.
