---
type: llm
---
The user asked a what-if question: what would happen if support staff could see every organization's orders. In app.py, users are admins or managers, each in one organization, and GET /orders returns every order to everyone.

PASS if the reply answers what would happen, from what app.py does today. Saying that nothing would break, because every user already sees every organization's orders, is a correct answer.

FAIL if the reply doesn't answer what would happen, such as one that only asks the user questions or only lays out a plan, or answers without saying anything about how app.py handles orders today.
