---
description: "A settings form gets an uncommitted, correct toggle-switch element: form-associated with setFormValue on every change, reset, disabled and restore callbacks, a switch role and checked state through ElementInternals, keyboard support, a property set before upgrade re-applied, and listeners only on the host. The reviewer finds nothing serious and invents no defect."
expected_outcome: "The review rates no problem High or Critical and claims none of the defects the element doesn't have (a stale or missing form value, leaked listeners, events that can't reach the form, reset or disabled not handled); with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Built a toggle-switch for the notification settings form. Can you review the uncommitted changes before I open the PR? I can't open files on this machine, so put the full review in your reply, exactly as written.
