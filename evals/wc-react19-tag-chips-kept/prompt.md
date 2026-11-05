---
description: "A React 19.3 app replaces its tag pills with the design system's tag-chips element, importing the definition before rendering, passing the tags array as a prop and listening with ontag-remove. React 19 sets props that exist on the element as properties and adds listeners for on-prefixed names with their case kept, so it works. The reviewer doesn't claim the props become strings or the event is never received, and reports nothing serious."
expected_outcome: "The review rates no problem High or Critical and doesn't claim that React passes the tags array as a string attribute or that ontag-remove attaches no listener; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Swapped our hand-rolled tag pills for the design system's tag-chips element, following the React docs page on custom elements. Could you review the uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
