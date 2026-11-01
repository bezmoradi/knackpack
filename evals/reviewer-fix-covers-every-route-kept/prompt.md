---
description: The same invoicing service fixes the cross-tenant invoice leak by making InvoiceRepository.get take the tenant id and filter on it in SQL, and both callers, get_invoice and the accounting CSV export, now pass the user's tenant. The adversarial reviewer doesn't claim the leak stays open through another path and finds nothing High or Critical.
expected_outcome: The review doesn't report that any invoice route still lets a user read, download or send another tenant's invoice, and raises nothing High, Critical or blocking; with the plugin, the adversarial reviewer ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I fixed the invoice leak from INC-0142 (the write-up is in docs/incidents). Run an adversarial review on the fix before I push it. It's uncommitted. I can't open files on this machine, so put the full review in your reply, exactly as written.
