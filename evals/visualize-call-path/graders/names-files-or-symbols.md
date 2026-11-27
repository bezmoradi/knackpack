---
type: llm
---

The user asked to be shown how a POST to /orders flows through a small Flask orders service. The repository's own parts on that path are the create_order route (orders/app.py), OrderService.place_order (orders/service.py), get_handler and the handler classes (orders/payments/registry.py, orders/payments/handlers.py), charge() (orders/payments/charging.py), OrderRepository.save (orders/repository.py) and OrderNotifier.send_confirmation with SmtpMailer (orders/notifications.py). Outside things such as the HTTP client, the SQLite database or the SMTP server aren't repository code. This is Claude's final reply.
PASS if, in the flow the reply shows, each part that is repository code is identified by a file path, a file and line, or a function, class or method name from the code, either on the node or step itself or in a key or list right next to it.
FAIL if any repository part of the flow is given only a generic label, such as "service layer", "payment provider", "database layer" or "notifications", with no file or symbol for it anywhere in the reply, or if the reply shows no flow. Count anything the reply doesn't show as a FAIL.
