---
type: tool_used
tool: Write
# The page is written with the Write tool as visualize-<topic>.html at an
# absolute path: the session scratchpad named in the system prompt, whose path
# needn't contain claude-<id>/, or the private claude-<id> folder.
# page-outside-repo fails a page written inside the workspace.
input_match: '"file_path"\s*:\s*"/[^"]*/visualize-[^"/]*\.html"'
min: 1
arm: with-only
---
