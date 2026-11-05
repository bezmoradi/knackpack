---
description: "A React 18.3 app replaces its tag pills with the design system's tag-chips element, passing the tags array as a prop and listening with ontag-remove as React 19's documentation shows. React 18 sets every prop on a custom element as a string attribute and drops unknown on* handlers, so the chips render empty and removing a tag does nothing. The reviewer reports the interoperability failure for the project's React version."
expected_outcome: "The review reports that in React 18 (the project's version) the tags array reaches the element as an attribute string rather than the tags property, so no chips render, and that ontag-remove attaches no listener, and grades it High, or Medium and blocking; with the plugin, the reviewer ran."
tags: [wc-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Swapped our hand-rolled tag pills for the design system's tag-chips element, following the React docs page on custom elements. Could you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
