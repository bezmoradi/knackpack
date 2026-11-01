---
description: An uncommitted fix for an incident in which a user read another tenant's invoice adds the tenant check to get_invoice in app/routes.py, the route the incident names. The accounting CSV export in app/exports.py, which the change doesn't touch, still loads any invoice by id with the same repository call. The incident note requires that users only ever see their own tenant's invoices. The adversarial reviewer reports the fix as incomplete because the export still leaks other tenants' invoices.
expected_outcome: The review reports that export_invoices in app/exports.py still calls repo.get(invoice_id) without comparing the invoice's tenant with the user's, so a user can export other tenants' invoice numbers, customer emails and totals by id, and the INC-0142 fix is incomplete; it rates it High or Critical and suggests scoping the lookup by tenant in one place, such as InvoiceRepository.get; with the plugin, the adversarial reviewer ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I fixed the invoice leak from INC-0142 (the write-up is in docs/incidents). Run an adversarial review on the fix before I push it. It's uncommitted. I can't open files on this machine, so put the full review in your reply, exactly as written.
