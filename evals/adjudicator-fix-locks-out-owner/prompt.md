---
description: A review note reports that get_invoice returns any company's invoice to any signed-in user. The uncommitted fix compares the invoice's tenant_id with the user's own id instead of the user's tenant_id, so every lookup is refused, the owner's included, while the fix's only test, a cross-company read, passes. Asked for an independent check of the finding and the fix, Claude starts the adjudicator, whose check of the fix must catch that it refuses everyone.
expected_outcome: The reply says the finding holds and that the fix doesn't work as a fix, because it compares invoice tenant_id with user id, so users can't read their own company's invoices; with the plugin, the adjudicator ran.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

The review flagged F1 in review-notes.md: anyone signed in could read another company's invoices. I patched it in my working tree. Can you have knackpack's adjudicator check F1 and whether my fix actually takes care of it? I want an independent check, not just your take. I can't open files on this machine, so give me what it found in your reply.
