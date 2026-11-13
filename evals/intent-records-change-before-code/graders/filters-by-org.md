---
type: llm
focus: { source: file, path: app.py }
---
PASS if, in app.py as it is after the run, `list_orders` (or whatever GET /orders now calls) returns a manager only the orders whose `org_id` matches the manager's own `org_id`, and still returns every order to an admin.

FAIL if a manager can still get another organization's orders, if admins no longer get every order, if a manager gets no orders at all, or if the file doesn't show the behavior clearly enough to tell.
