---
description: "A design system that names everything BEM-style (block__element--modifier, is-* states) gets an uncommitted review widget with camelCase classes, a global .active class, a descendant .title selector and a padding declared twice with different values in one rule. The CSS reviewer reports the naming drift, the leaking global names and the duplicate declaration, without grading them High."
expected_outcome: "The review reports the camelCase and generic class names that break the project's BEM convention (and that .active or .title can leak), and the conflicting duplicate padding, at Low or Medium, with nothing High."
tags: [css-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

Added the star-rating review widget to our design system package. Review the CSS please. I can't open files on this machine, so put the full review in your reply, exactly as written.
