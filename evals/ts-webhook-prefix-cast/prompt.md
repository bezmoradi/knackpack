---
description: "A billing webhook handler checks event.type.startsWith(\"invoice.\") and then asserts the event is InvoicePaid before calling markInvoicePaid. The provider also sends invoice.voided and invoice.payment_failed, listed in events.ts, so voided and failed invoices are recorded as paid. The reviewer reports the assertion the check doesn't support."
expected_outcome: "The review reports that the startsWith(\"invoice.\") check doesn't establish that the event is InvoicePaid, so the `as InvoicePaid` assertion lets invoice.voided and invoice.payment_failed mark invoices paid (with no amount), and grades it High or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

hey, I wired up invoice payments in the billing webhook. could you have someone review the TS in what I haven't committed yet? I can't open files on this machine, so put the full review in your reply, exactly as written.
