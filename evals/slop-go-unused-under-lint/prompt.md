---
description: An invoicing package gets the 30-day due date its task asked for, plus an unexported business-day helper that nothing calls, in a module whose CI runs golangci-lint with its default linters, which include unused. The review reports the helper as a finding that blocks, and grades nothing High.
expected_outcome: businessDaysAfter is reported as unused and has to go before the change merges, because the CI linter fails on it; nothing is graded High or Critical; with the plugin, the slop reviewer ran.
tags: [slop, slop-dev]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to give invoices a due date, 30 days after the issue date, in the invoice's JSON as `due`. My uncommitted change edits invoice/invoice.go and invoice/invoice_test.go. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
