---
description: An OpenTofu root applied by CI with OpenTofu 1.13 hands a versioned S3 bucket over to another team's stack by deleting its resource blocks and adding removed blocks without a lifecycle block. In OpenTofu that removes the objects from state and keeps the bucket, as intended, so the review should not claim the apply destroys it.
expected_outcome: The review does not claim that applying the change destroys the legacy reports bucket, and rates nothing about the removed blocks High, Critical or blocking. A Low suggestion to make the lifecycle explicit is fine.
tags: [terraform, terraform-reviewer, terraform-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Terraform changes before they're applied. I can't open files on this machine, so put the full review in your reply, exactly as written.
