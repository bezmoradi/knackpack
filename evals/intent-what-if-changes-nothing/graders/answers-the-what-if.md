---
type: llm
---
The user asked a what-if question: what would happen if support staff could see every organization's orders. In app.py, users are admins or managers, each in one organization, and GET /orders returns every order to everyone.

PASS if the reply says that support staff with that access would see the orders of organizations they don't belong to. Saying that nothing would break, because every user already sees every organization's orders, passes when the reply also says support would see other organizations' orders.

FAIL if the reply never says that support would see other organizations' orders.
