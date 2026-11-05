---
description: "In a JavaScript project checked with checkJs and strict, the change adds findCustomer with @returns {Promise<Customer>}, but it returns getJson(...), which is typed Promise<any> and documented to resolve to null on a 404. resendReminders reads customer.email, so one unknown or deleted customer id throws a TypeError and stops the whole batch. The reviewer reports the JSDoc contract that hides the null."
expected_outcome: "The review reports that findCustomer's @returns {Promise<Customer>} is wrong because getJson resolves to null on a 404 (its any return lets the annotation through), so resendReminders dereferences null at customer.email and the batch throws, skipping the remaining ids; it recommends @returns {Promise<Customer | null>} (which checkJs with strict then enforces at callers) plus handling the missing customer, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Support wanted a way to resend renewal reminders to specific customers, so I added one. It's JS but we type-check it with tsc. Can you review what I haven't committed? I can't open files on this machine, so put the full review in your reply, exactly as written.
