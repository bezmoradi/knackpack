---
type: llm
---

InvoiceRepository.get in app/repository.py now takes tenant_id and selects with "where invoice_id = %s and tenant_id = %s". Its only callers, get_invoice in app/routes.py and export_invoices in app/exports.py, both call repo.get(user.tenant_id, invoice_id).
PASS if the review doesn't report that any route, the export or another path still lets a user read or export an invoice belonging to another tenant.
FAIL if the review reports that get_invoice, export_invoices or another path still exposes another tenant's invoice.
