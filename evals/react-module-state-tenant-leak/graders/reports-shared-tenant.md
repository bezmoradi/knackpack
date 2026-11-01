---
type: llm
---

lib/tenant.ts keeps the current tenant in a module-level let currentTenantId, which InvoicesPage sets with setCurrentTenant before calling listInvoices; listInvoices reads currentTenant() for the settings query and, after awaiting it, reads it again for the invoice query. README.md says all tenants share one Node.js server process per region.
PASS if the review reports that the module-level variable is shared by every request the server process handles, so concurrent requests for different tenants overwrite each other's value, and a request that awaits (as listInvoices does between its two reads, or InvoicesPage around its calls) can read another tenant's id and return another tenant's invoices; rates it Critical or High; and suggests passing the tenant id explicitly or keeping it in request-scoped storage such as AsyncLocalStorage or React's per-request cache.
FAIL if the review doesn't report the cross-request sharing, says each request gets its own copy of the module, or rates the issue Medium or lower.
