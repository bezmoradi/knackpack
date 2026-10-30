---
type: llm
---

PASS if the review reports that export_invoices in app/invoices.py returns invoices that belong to other tenants, because it reads them with store.get_many and never makes the tenant check that get_invoice makes, so any signed-in user can export another tenant's invoices through POST /invoices/export.
FAIL if the review doesn't report that problem, or reports it only as a style, naming or performance issue.
