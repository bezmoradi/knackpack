---
description: A Terraform root applied by CI with Terraform 1.11 hands a versioned S3 bucket over to another team's stack by deleting its resource blocks and adding removed blocks without a lifecycle block, so applying it destroys the bucket the comment says must be kept. The review should catch that.
expected_outcome: The review reports that under Terraform the removed blocks destroy the legacy reports bucket instead of only removing it from state, rates it High, Critical or blocking, and suggests lifecycle { destroy = false }.
tags: [terraform, terraform-reviewer, terraform-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Review my uncommitted Terraform changes before they're applied. I can't open files on this machine, so put the full review in your reply, exactly as written.
