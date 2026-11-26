---
type: llm
---

The user asked for a quick picture of what calls charge(), defined in orders/payments/charging.py. Exactly three functions call it directly: OrderService.place_order in orders/service.py (the call is at orders/service.py:39), retry_failed_payments in orders/jobs.py (orders/jobs.py:17), and recharge_order in orders/app.py, the route for POST /orders/<order_id>/charge (orders/app.py:58). create_order, the POST /orders route, reaches it only through place_order. Nothing else calls it: OrderService.estimate_charge has a similar name but only adds up a basket, the handler classes' authorize and capture are called by charge() rather than calling it, and there is no refund, webhook or subscription code. A caller may be named by its function or method, by its route, by its file, or by file and line; a file and line at or near one of the three calls counts as that caller. This is Claude's final reply.
PASS if the reply shows all three direct callers: place_order (or orders/service.py), retry_failed_payments (or orders/jobs.py) and recharge_order (or its route, or orders/app.py:58).
FAIL if any of the three is missing from the reply. Count anything the reply doesn't show as a FAIL.
