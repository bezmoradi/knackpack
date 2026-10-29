---
description: A TypeScript module computes shipping rates through an abstract class, three one-method subclasses and a static factory switching on a string. The assessment proposes a plainer TypeScript form, such as a function per rate keyed in a map or a discriminated union, with a concrete benefit, and doesn't grade the working code a defect.
expected_outcome: A simpler form is proposed (a record of functions, a function type, or a union with an exhaustive switch) with its benefit named; the current code is called correct but heavier than needed, not defective.
tags: [pattern, pattern-dev]
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

Is the Shipping hierarchy in src/shipping.ts the right design for these three rates in TypeScript? If there's a plainer way that keeps the same behavior, show me the shape and what we gain.

I can't open files on this machine, so put the full review in your reply, exactly as written.
