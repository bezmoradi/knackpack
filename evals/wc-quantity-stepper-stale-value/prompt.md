---
description: "An order form replaces its number input with a form-associated quantity-stepper element. The element calls setFormValue once in connectedCallback and never again when the buttons change the quantity, so the form always submits the initial quantity. The reviewer reports the broken form integration."
expected_outcome: "The review reports that setFormValue is only called when the element connects, so the plus and minus buttons change the displayed quantity but the form submits the original value, and grades it High, or Medium and blocking; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Swapped the plain number input on the order form for our own quantity-stepper so it matches the design. Please review the uncommitted changes. I can't open files on this machine, so put the full review in your reply, exactly as written.
