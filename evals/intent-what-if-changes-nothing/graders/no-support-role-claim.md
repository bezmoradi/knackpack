---
type: llm
---
The user asked what would happen if support staff could see every organization's orders. In app.py, users are only admins or managers; there is no support role.

PASS if the reply doesn't say that app.py already has a support role or support users.

FAIL if the reply says that app.py already has a support role or support users.
