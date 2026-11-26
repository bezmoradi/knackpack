---
description: The orders service plus docs/notifications-queue.md, a proposal marked "proposed, not started" to move the confirmation email onto an SQLite outbox table drained by a new worker. Today OrderService.place_order calls OrderNotifier.send_confirmation inline after saving the order, and it sends through SmtpMailer with sleeps between retries; no outbox, worker or queue exists in the code. With the skill, Claude labels the queue flow Proposed and keeps it out of today's flow.
expected_outcome: The reply shows today's inline flow and the queue flow, labels the queue flow Proposed (or otherwise as not built), and today's flow has no outbox, worker or queue.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize how order notifications work today and how they'd work with the queue idea in docs/notifications-queue.md. A teammate wrote it up and wants a decision next week, I'm trying to get my head around what actually changes.
