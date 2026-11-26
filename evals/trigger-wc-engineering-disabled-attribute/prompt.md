---
description: The user asks for a disabled attribute on an existing custom element. Changing a custom element starts the Web Components engineering skill on its own; the Web Components reviewer, which reviews only when asked, doesn't start.
expected_outcome: The web-components-engineering skill loads, and the knackpack Web Components reviewer never runs.
tags: [trigger, "starts:knackpack:web-components-engineering", "quiet:knackpack:web-components-code-reviewer"]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Edit, Agent, Skill]
---

Can you add a `disabled` attribute to `<copy-button>` in src/copy-button.js? When it's set, clicking shouldn't copy anything, and it should look and behave like a disabled button.
