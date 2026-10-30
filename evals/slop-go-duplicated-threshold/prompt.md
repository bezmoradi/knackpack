---
description: A shop makes shipping free from $50 by copying the same threshold check, with the literal 5000, into the cart preview and the checkout, although a pricing package already holds the shipping charge both use. The review reports the copied rule and suggests one shared definition, and grades nothing High.
expected_outcome: The free-shipping rule duplicated in cart/preview.go and checkout/checkout.go is reported, with one shared function or constant (such as in pricing) suggested; nothing is graded High or Critical; with the plugin, the slop reviewer ran.
tags: [slop, slop-holdout]
runs: 1
max_turns: 20
timeout_seconds: 1800
allowed_tools: [Read, Glob, Grep, Agent]
---

The task was to make shipping free for orders of $50 or more, both in the cart preview and at checkout. My uncommitted change is in cart/preview.go and checkout/checkout.go. Check it for slop: anything it adds that we don't need.

I can't open files on this machine, so put the full review in your reply, exactly as written.
