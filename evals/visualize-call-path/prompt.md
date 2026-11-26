---
description: The orders service. POST /orders goes create_order -> OrderService.place_order -> get_handler(settings.payment_provider) -> charge() -> OrderRepository.save -> OrderNotifier.send_confirmation. The payment handler comes from a registry keyed by a provider name that settings.toml sets to "sandbox" and every deployment overrides with ORDERS_PAYMENT_PROVIDER, so the code doesn't settle which handler runs. orders/cache.py's order_cache is used only by GET /orders/<order_id>, never on the POST path. With the skill, Claude draws only what the code has, labels the config-selected hop Inferred or Unknown, and names files or symbols.
expected_outcome: One visual of the POST /orders path with no node or edge the code lacks (no cache on it), the handler choice shown as depending on configuration and labelled Inferred or Unknown rather than a plain edge to one handler, and a file or symbol for each repository node.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize how a POST to /orders flows through the code, from the route down to wherever it ends up. I'm new on this repo and about to pick up some work in the orders API, just want the big picture before I touch anything.
