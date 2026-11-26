---
type: regex
target: last_message
# The reply gives the page's absolute path, ending /visualize-<topic>.html. Any
# folder passes here, since the session scratchpad needn't contain claude-<id>/;
# page-outside-repo fails a page written inside the workspace.
pattern: '(?:^|[\s"''`(])/[^\s"''`]*/visualize-[^/\s"''`]*\.html'
arm: with-only
---
