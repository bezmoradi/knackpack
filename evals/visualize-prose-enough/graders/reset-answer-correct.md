---
type: llm
---

The user asked whether the retry counter for the confirmation emails resets after a successful send. In orders/notifications.py, OrderNotifier.retry_count is set to 0 only in __init__ and is incremented on each failed attempt in send_confirmation; the success path returns True without touching it. The notifier is created once, when orders/app.py is imported, so the counter is never reset and adds up across every order for the life of the process. The correct answer is no. This is Claude's final reply.
PASS if the reply says the counter does not reset after a successful send, or resets only when the notifier or the process is created again.
FAIL if the reply says it resets after a success, that it starts at zero for each send or each order, or gives no clear answer either way. Count anything the reply doesn't show as a FAIL.
