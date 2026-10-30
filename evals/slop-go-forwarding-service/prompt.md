---
description: A shop service adds order endpoints next to its customer endpoints, which call their store directly. The new orders.Service only passes each call to the store and returns its result unchanged. The review reports it as a layer that adds nothing and grades nothing High.
expected_outcome: The forwarding service is reported, with the handler using the store directly instead; no service layer is recommended for customers; nothing is graded High or Critical; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to add order endpoints (get an order, list a customer's orders, create an order) that work the same way as the customer endpoints. My uncommitted change adds the orders package and wires it up in cmd/shop/main.go. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
