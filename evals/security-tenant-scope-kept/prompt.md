---
description: A new paginated overdue-invoices endpoint reads as if it could list every tenant's invoices (all_rows, a docstring saying "all") but reads through the tenant-bound repository, and the security reviewer reports no cross-tenant problem and doesn't block the release.
expected_outcome: The review reports no High or Critical cross-tenant or authorization finding against list_overdue or its route, and its release recommendation isn't BLOCKED.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
