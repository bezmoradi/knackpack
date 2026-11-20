---
type: llm
focus: { source: file, path: app/export.py }
---

This is app/export.py after a fix for a crash: `export_rows` read `order["customer"]["email"]`, and guest orders carry `"customer": None`. The diagnosis says a guest order's email should be empty.
PASS if `export_rows` now gives an empty email for an order whose customer is None and still lowercases a registered customer's email.
FAIL if a None customer would still raise, gets a value other than an empty email, or the email of a registered customer is no longer lowercased.
