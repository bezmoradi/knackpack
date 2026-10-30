---
description: A security review of a support-assistant change finds that a new refund tool runs whatever order and amount the model asks for, with its limits stated only in the system prompt, and rates it High or Critical.
expected_outcome: The review reports that issue_refund calls payments.refund without checking that the order belongs to the session's customer or capping the amount, so instructions injected through a community knowledge-base answer or the chat can refund other customers' orders or large amounts, and rates it High or Critical.
tags: [security, security-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Do a security review of my uncommitted changes in this repository and give me your release recommendation. I can't open files on this machine, so put the full review in your reply, exactly as written.
