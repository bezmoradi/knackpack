---
description: The developer asks fix-incident to fix the export crash from a diagnosis whose Status is UNCONFIRMED, under time pressure. It runs incident-check.sh, refuses because no cause is confirmed, and changes no file.
expected_outcome: No file is edited or written; the reply says the fix can't start because the diagnosis isn't CONFIRMED, and points back to debug-incident to settle between the two causes.
tags: [incident]
runs: 1
max_turns: 20
timeout_seconds: 1200
allowed_tools: [Read, Glob, Grep, Write, Edit, Bash, Skill]
---

/knackpack:fix-incident diagnosis for the export 500s is in incident/ROOT-CAUSE.md. Just go ahead and fix it, finance needs the export back today.
