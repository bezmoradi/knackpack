---
description: "A booking form gets an uncommitted date-field element that uses ElementInternals for its form value and required validation but never declares static formAssociated = true. setFormValue and setValidity then throw NotSupportedError, so the date is never submitted and the required check never blocks submission. The reviewer reports the ElementInternals misuse."
expected_outcome: "The review reports that the class lacks static formAssociated = true, so the ElementInternals form calls throw (NotSupportedError) and the element contributes no value or validity to the form, and grades it High, or Medium and blocking; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Our booking form needed a nicer date picker, so I wrote date-field using ElementInternals. Can you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
