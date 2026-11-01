---
description: To erase an account's activity history when the account is deleted, a migration adds a foreign key from account_events.account_id to accounts with ON DELETE CASCADE (NOT VALID, then VALIDATE), and the DELETE /account handler now deletes the account row. Nothing indexes account_events.account_id, so each deletion's cascade scans the whole 600-million-row table, past the service's 30-second statement_timeout. The review should catch that.
expected_outcome: The review reports that account_events.account_id has no index, so every account deletion's cascade scans all of account_events, rates it Medium or higher or blocking, and suggests an index on account_events (account_id), built concurrently before the cascade is relied on.
tags: [database, database-reviewer, database-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Privacy asked that deleting an account also wipes its activity history, so I added a cascading foreign key and made the endpoint actually delete the account. Review my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
