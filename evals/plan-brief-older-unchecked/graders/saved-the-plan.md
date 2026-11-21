---
type: tool_used
tool: Write
# The skill saves its plan as PLAN.md or PLAN-<name>.md; an older brief is
# planned from as before, so the plan file gets written.
input_match: '"file_path"\s*:\s*"[^"]*PLAN[^"/]*\.md"'
min: 1
arm: with-only
---
