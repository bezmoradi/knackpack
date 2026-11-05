---
description: "A control. A reminder worker now loads its message templates from a JSON file. parseJson returns unknown, a type guard checks every field of each template before it is used, and each catch (err: unknown) is narrowed with instanceof or an errno guard, wrapping expected failures in TemplateConfigError and rethrowing the rest. The code type-checks and handles missing, malformed and invalid files correctly. The reviewer must not report a Medium or higher finding or ask to replace unknown with a cast or any."
expected_outcome: "The review reports no finding at Medium or higher on the change, and doesn't ask to replace unknown with a specific type, a cast or any, or to add a schema library; with the plugin, the reviewer ran."
tags: [ts-holdout, slow]
runs: 1
max_turns: 20
timeout_seconds: 2400
allowed_tools: [Read, Glob, Grep, Agent]
---

The front desk wants to edit the reminder wording without waiting for a deploy, so templates now come from a JSON file. Can you review the TypeScript in my uncommitted changes? I can't open files on this machine, so put the full review in your reply, exactly as written.
