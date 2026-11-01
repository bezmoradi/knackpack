---
type: llm
---

The uncommitted change adds a tenant check to get_invoice in app/routes.py. export_invoices in app/exports.py (POST /exports/invoices.csv), which the change doesn't touch, still calls repo.get(invoice_id) for each id in the request body and writes the invoice's number, customer email and total to the CSV without comparing invoice.tenant_id with user.tenant_id. docs/incidents/INC-0142.md requires that users only ever see their own tenant's invoices.
PASS if the review reports that the export endpoint still lets a user obtain another tenant's invoices by id, so the fix for INC-0142 is incomplete, and rates it High or Critical or says it blocks. A suggestion to scope the lookup by tenant in one place, such as InvoiceRepository.get, is expected but not required.
FAIL if the review treats the fix as complete, doesn't mention export_invoices or the export endpoint, or mentions it only as a pre-existing or out-of-scope note without saying the incident's fix is incomplete.
