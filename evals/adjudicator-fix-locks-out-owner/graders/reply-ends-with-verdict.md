---
type: regex
arm: with-only
target: trace
# The adjudicator's reply to the reviewer or main session ends with its
# verdict line, on a line of its own; it has no findings line. Only blank lines
# may follow the verdict before the reply ends: the JSON string's closing
# quote, the Agent result's agentId footer, or a notification's </result>. In
# the trace, a line break is the two characters \n.
pattern: '(\\n|^)\s*knackpack-verdict/1: (pass|block)(\\n|\s)*("|\\nagentId: |</result>)'
---
