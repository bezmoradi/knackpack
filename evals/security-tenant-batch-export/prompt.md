---
description: An uncommitted batch invoice export reads invoices by ID without the tenant check the single-invoice read makes, and the security reviewer reports the cross-tenant read, rates it High or Critical and blocks the release.
expected_outcome: The review names export_invoices, says it returns other tenants' invoices because it skips the tenant check get_invoice makes, rates that High or Critical, and recommends BLOCKED.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
