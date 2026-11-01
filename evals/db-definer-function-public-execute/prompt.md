---
description: A billing service moves voiding an invoice into a SECURITY DEFINER function owned by the tables' owner, grants EXECUTE to the service's role and never revokes the EXECUTE PostgreSQL gives PUBLIC on new functions, so the read-only support role can void invoices in any organization. The function also sets no search_path, so a caller's temporary table named invoice_audit, with INSERT granted to PUBLIC, receives the audit row. The review should catch both.
expected_outcome: The review reports that support_ro, or any role, can execute void_invoice because EXECUTE was never revoked from PUBLIC, rates it High, Critical or blocking and suggests revoking it; and reports the missing search_path with a fix such as SET search_path on the function or schema-qualified names.
tags: [database, database-reviewer, database-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I moved invoice voiding into a database function so the audit row can't be skipped. Can you review the migration and the app change before I push? It's all uncommitted. I can't open files on this machine, so put the full review in your reply, exactly as written.
