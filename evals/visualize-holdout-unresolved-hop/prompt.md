---
description: A FastAPI orders app with an in-process event bus. POST /orders/{id}/cancel goes cancel_order -> OrderService.cancel -> OrderRepository.set_status -> bus.publish("order.cancelled"). Its handlers are loaded at startup from subscriptions.yaml, or the file EVENTS_SUBSCRIPTIONS names, which production sets, by dotted path with importlib. The repository's file names refund_payment and release_stock; send_cancellation_email exists but isn't subscribed. With the skill, Claude labels the subscriber hop Inferred or Unknown and doesn't draw the email handler as subscribed.
expected_outcome: The handlers after publish are shown as coming from the subscription config and labelled Inferred or Unknown, not as plain fixed calls; send_cancellation_email isn't shown as running on cancel.
tags: [visualize, visualize-holdout]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize what happens when an order gets cancelled through the API, including everything that kicks off afterwards.
