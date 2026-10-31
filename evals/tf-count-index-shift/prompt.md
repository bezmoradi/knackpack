---
description: A Terraform root creates one S3 bucket per list entry with count. Removing the retired exports bucket from the middle of the list shifts the indexes after it, so the plan replaces one bucket with the audit-log bucket's name and destroys the audit-log bucket, which must be kept for seven years. The review should catch that.
expected_outcome: The review reports that removing shop-exports from the middle of the count list shifts the indexes so the audit-log bucket is replaced or destroyed, rates it High, Critical or blocking, and suggests for_each with moved blocks or an equivalent.
tags: [terraform, terraform-reviewer, terraform-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Terraform changes before they're applied. I can't open files on this machine, so put the full review in your reply, exactly as written.
