---
description: An uncommitted change adds an invoice download endpoint that joins the caller's organization folder with a file name from the query string and guards it with strings.HasPrefix on the cleaned path, which accepts ../<org whose slug starts the same>/file, so one organization can read another's invoices. The Go reviewer reports the cross-organization read as High or Critical.
expected_outcome: The review says the HasPrefix check lets a name such as ../acme-labs/x.pdf through for the org acme, reaching another organization's folder, and grades it High or Critical, or blocking.
tags: [go-reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

hey, can you review my uncommitted go changes? it's the new invoice download endpoint for the billing service. I can't open files on this machine, so put the full review in your reply, exactly as written.
