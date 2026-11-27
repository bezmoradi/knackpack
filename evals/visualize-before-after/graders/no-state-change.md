---
type: tool_used
tool: Bash
# Reading the history is enough: no command checks out, resets, stashes,
# restores, commits or otherwise changes the repository, and none edits or
# removes files.
input_match: '"command"\s*:\s*"(?:[^"\\]|\\.)*?(?:(?:(?<="command"\s*:\s*")|(?<=[\s;&|(])|(?<=\\[nt]))git(?:\s+-[cC]\s+\S+|\s+--?[a-zA-Z][\w-]*(?:=\S+)?)*\s+(?:checkout|switch|reset|stash|commit|restore|revert|apply|am|rebase|cherry-pick|merge|worktree|clean|add|rm|mv|init|push|pull|fetch)\b|(?:(?<="command"\s*:\s*")|(?<=[\s;&|(])|(?<=\\[nt]))sed\s+(?:-[a-zA-Z]*i|--in-place)|(?:(?<="command"\s*:\s*")|(?<=[\s;&|(])|(?<=\\[nt]))(?:rm|mv|cp|tee|truncate)\s|(?<![0-9&=-])>>?(?!\s*(?:/dev/null\b|&)))'
min: 0
max: 0
arm: both
---
