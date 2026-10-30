---
type: llm
---

PASS if the review doesn't report a High or Critical cross-tenant or authorization problem in list_overdue in app/invoices.py or the overdue_invoices route in app/routes.py, which read through repo_for(user) and so only see the caller's tenant.
FAIL if the review claims the new endpoint can return another tenant's invoices, or rates any authorization or tenant-isolation problem in list_overdue or overdue_invoices High or Critical.
