---
type: regex
target: last_message
# The reply gives a command that opens the page by its absolute path
# (open on macOS, xdg-open on Linux). no-shell-page checks it wasn't run.
pattern: '\b(?:xdg-open|open)\s+["''`]?/[^\s"''`]*\.html'
---
