---
description: A Go cart computes its total with a discount passed as a function value. Asked whether that is a legitimate Strategy or should become an interface with one type per discount, the assessment accepts the function and demands no hierarchy.
expected_outcome: The function-valued Discount is judged appropriate; no conversion to an interface or a type per discount is recommended.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

In pricing/, Cart.Total takes a Discount that's just a func type. Is that a legitimate Strategy pattern, or should it be an interface with a separate type per discount? Validate it.

I can't open files on this machine, so put the full review in your reply, exactly as written.
