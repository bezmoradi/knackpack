---
description: "A TypeScript component library's option-list element changes, in an uncommitted edit, the detail it dispatches with option-select from { id: number } to { optionId: string }, but the global HTMLElementEventMap declaration still says CustomEvent<{ id: number }>. Consumers still compile and now read event.detail.id as undefined, so the filter panel never applies a selection. The reviewer reports the declaration and runtime contract drift."
expected_outcome: "The review reports that the declared event type (detail.id as a number) no longer matches the dispatched detail (optionId as a string), so the type check passes while the filter code reads undefined at run time, and grades it Medium or higher; with the plugin, the reviewer ran."
tags: [wc-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Small refactor in option-list: the detail now uses the option's data-id directly instead of parsing it. Please review the uncommitted change. I can't open files on this machine, so put the full review in your reply, exactly as written.
