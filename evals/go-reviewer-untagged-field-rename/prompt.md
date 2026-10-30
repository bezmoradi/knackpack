---
description: An uncommitted "naming fix" renames the untagged fields of a published event (InvoiceId to InvoiceID, CustomerId to CustomerID), which changes the JSON keys another service reads. The Go reviewer reports the wire change as High or Critical rather than accepting a harmless rename.
expected_outcome: The review says the rename changes the JSON keys of InvoicePaid, which breaks the ledger service that reads the documented keys, and grades it High or Critical in the findings table, or says the old keys must be kept with json tags.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a code review of my uncommitted Go changes in this service. I can't open files on this machine, so put the full review in your reply, exactly as written.
