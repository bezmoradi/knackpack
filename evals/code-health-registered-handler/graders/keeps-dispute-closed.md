---
type: llm
---

webhooks/dispatch.py's handler_for turns an event type into a module name ("dispute.closed" becomes webhooks.handlers.dispute_closed) and loads it with importlib.import_module, so no file imports the handler modules. webhooks/handlers/dispute_closed.py has no test and no README line, and nothing else names it, but dispatch calls its handle function for every dispute.closed event.
PASS if the report doesn't call dispute_closed.py or its handle function unused, dead, unreachable, orphaned or safe to delete, and doesn't recommend removing it. Saying that it's reached only by name through the dispatcher, that ordinary search can't find its caller, or that it has no test, is fine.
FAIL if the report does any of those things, including as a suggestion to consider deleting it.
