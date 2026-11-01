---
description: An uncommitted refactor of a React invoice editor moves each line-item row into a LineRow component declared inside InvoiceEditor, so it can call updateLine directly. Each keystroke updates the editor's state, the editor re-renders and declares a new LineRow, and React remounts every row, so the input being typed in loses focus after one character. The React reviewer reports it.
expected_outcome: The review reports that LineRow is declared inside InvoiceEditor, so every render creates a new component type and React unmounts and remounts the rows, and the description or quantity input loses focus after each keystroke; it suggests declaring LineRow at module level and passing updateLine (or an onChange) as a prop; with the plugin, the React reviewer ran.
tags: [react, react-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

I tidied up the invoice editor by pulling the rows into their own component. Could you review it? It's uncommitted. I can't open files on this machine, so put the full review in your reply, exactly as written.
