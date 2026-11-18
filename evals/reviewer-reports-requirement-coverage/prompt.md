---
description: The adversarial reviewer, given two requirements with IDs, ends its reply with one knackpack-coverage/1 line for each, REQ-01 verified and REQ-02 violated, before its finding lines and the unchanged findings and verdict lines.
expected_outcome: The reviewer's reply has a coverage line for REQ-01 with status verified and one for REQ-02 with status violated, then the finding lines, the findings line and the verdict line, in that order.
tags: [reviewer, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added list_orders to app/orders.py but haven't committed it. Could you get it adversarially reviewed against what we agreed?

- REQ-01: list_orders returns only orders from the caller's own tenant.
- REQ-02: list_orders returns those orders newest first, by created_at.

I can't open files here, so paste the review into your reply.
