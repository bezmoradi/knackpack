---
description: "ListProps declares onSelect(item: ListItem): void with method shorthand. The new product picker passes (item: ProductItem) => cart.add(item.sku) while the list also contains selectable section headings that have no sku, so selecting a heading adds undefined to the cart. tsc accepts it because method parameters are checked bivariantly even under strictFunctionTypes. The reviewer reports the variance hole."
expected_outcome: "The review reports that the onSelect handler assumes every item is a ProductItem while headings (plain ListItems) also reach it, so cart.add receives undefined, explains that the method-shorthand declaration is why tsc accepts the narrower parameter, recommends declaring onSelect as a function-typed property (which makes tsc reject it) or narrowing the item in the handler, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [ts-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Built the product picker screen for the kiosk, with the menu split into sections. Please get my uncommitted TypeScript reviewed. I can't open files on this machine, so put the full review in your reply, exactly as written.
