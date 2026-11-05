---
description: "A project whose browserslist includes Firefox ESR 128 and Safari 17 adds an account menu positioned only with CSS anchor positioning, with no fallback; Firefox before 147 and Safari before 26 ignore it, so the menu renders at the corner of its containing block, away from its button. The CSS reviewer reports the missing fallback against the declared targets."
expected_outcome: "The review says anchor positioning isn't supported by Firefox 128 ESR or Safari 17 in the declared targets, so the menu is misplaced there without a fallback, and grades it Medium or higher."
tags: [css-dev, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Swapped our JS positioning library for native CSS anchor positioning on the account menu. Please review the CSS. I can't open files on this machine, so put the full review in your reply, exactly as written.
