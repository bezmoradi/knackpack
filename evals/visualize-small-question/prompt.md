---
description: 'The orders service. charge() in orders/payments/charging.py has three direct callers: OrderService.place_order (orders/service.py:39), retry_failed_payments (orders/jobs.py:17) and the recharge_order route for POST /orders/<order_id>/charge (orders/app.py:58). OrderService.estimate_charge has a similar name but doesn''t call it. A small question, so with the skill Claude answers with one visual and draws only, and all of, the real callers.'
expected_outcome: At most one diagram block in the reply (quoted code doesn't count); every function shown as calling charge() really calls it, and all three direct callers are shown.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 15
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize what calls charge()? quick one, just want a picture of it before I go changing its signature
