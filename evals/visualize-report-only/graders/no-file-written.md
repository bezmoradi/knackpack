---
type: tool_used
tool: Write
# The skill writes nothing but a page, and only when asked for one: no
# Write call to any file whose name doesn't end in .html.
input_match: '"file_path"\s*:\s*"(?![^"]*\.html")[^"]*"'
min: 0
max: 0
arm: both
---
