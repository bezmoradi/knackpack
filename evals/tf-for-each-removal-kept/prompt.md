---
description: A Terraform root creates one S3 bucket per list entry with for_each over the names. Removing the retired exports bucket from the middle of the list plans only that bucket's destroy, because for_each addresses buckets by name, so the review should not claim the other buckets are replaced.
expected_outcome: The review does not claim the invoices or audit-log buckets are replaced or destroyed, and rates nothing about the removal High, Critical or blocking. A note to confirm the exports bucket is empty is fine.
tags: [terraform, terraform-reviewer, terraform-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Terraform changes before they're applied. I can't open files on this machine, so put the full review in your reply, exactly as written.
