---
description: The user asks for a tag on two S3 buckets in a Terraform file. That's a change to make; knackpack's Terraform reviewer, which reviews only when asked, doesn't start.
expected_outcome: The Terraform reviewer never runs.
tags: [trigger, "quiet:knackpack:terraform-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

Finance wants every payments bucket tagged. Add `cost-center = "payments"` to both buckets in main.tf.
