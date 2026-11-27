---
type: llm
---

The user asked to see how order notifications work today and how they would work under the proposal in docs/notifications-queue.md. Today, OrderService.place_order (orders/service.py) calls OrderNotifier.send_confirmation (orders/notifications.py) inline after saving the order; it renders CONFIRMATION_TEMPLATE and sends through SmtpMailer, sleeping between retries, inside the request. The proposal, whose status line reads "proposed, not started", adds an outbox table written in the order's transaction, a notify_worker process that polls it and sends, per-row attempts with backoff, and an outbox_dead table. None of those exist in the code. This is Claude's final reply.
PASS if the reply shows the queue or outbox flow and marks it as not built yet in any clear way: a label such as Proposed, planned or not built; a heading or sentence that puts it in the conditional, such as "How it would work with the queue", "With the proposal" or "If we adopt the proposal"; or new parts marked as new.
FAIL if the queue flow is shown as if it were how the code works now, if the reply says the outbox, the worker or a queue already exists, or if it doesn't show the proposed flow at all. Count anything the reply doesn't show as a FAIL.
