---
type: llm
---

The user asked to see how order notifications work today and how they would work under the proposal in docs/notifications-queue.md. Today, OrderService.place_order (orders/service.py) calls OrderNotifier.send_confirmation (orders/notifications.py) inline after saving the order; it renders CONFIRMATION_TEMPLATE and sends through SmtpMailer, sleeping between retries, inside the request. The proposal, whose status line reads "proposed, not started", adds an outbox table written in the order's transaction, a notify_worker process that polls it and sends, per-row attempts with backoff, and an outbox_dead table. None of those exist in the code. This is Claude's final reply.
PASS if the flow the reply gives for today has the email sent inline from place_order through send_confirmation and SmtpMailer, with no outbox, worker or queue in it.
FAIL if today's flow includes an outbox, a worker, a queue or any other part of the proposal, or if the reply doesn't show today's flow. Count anything the reply doesn't show as a FAIL.
