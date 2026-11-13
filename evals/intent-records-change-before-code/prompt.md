---
description: A change request that sets an access rule, managers seeing only their own organization's orders while admins still see all, with intent tracking on. Claude writes the rule into the session's intent record before it edits app.py, then makes the change.
expected_outcome: The intent record is written, with the rule as an agreed requirement, before the first edit to app.py, and list_orders returns a manager only their organization's orders while admins still get every order.
tags: [intent]
runs: 1
max_turns: 25
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Edit, Write]
---

managers should only see orders from their own org in GET /orders, admins still see everything. can you make that change in app.py
