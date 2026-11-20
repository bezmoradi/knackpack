---
description: The coverage case run with no shell granted, so the reviewer can't run its count command and writes the reply's lines itself. It still ends with a knackpack-coverage/1 line for REQ-01 (verified) and REQ-02 (violated), in order, a knackpack-finding/1 line for the sorting defect, the findings line and the verdict line.
expected_outcome: The reviewer's reply, which carries the full report since it can't write the file either, ends with the coverage line for REQ-01 verified and REQ-02 violated, a finding line for F1, then the findings line and the verdict line, in that order, each in the command's format.
tags: [reviewer-noshell, slow, "starts:knackpack:adversarial-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I added list_orders to app/orders.py but haven't committed it. Could you get it adversarially reviewed against what we agreed?

- REQ-01: list_orders returns only orders from the caller's own tenant.
- REQ-02: list_orders returns those orders newest first, by created_at.

I can't open files here, so paste the review into your reply.
