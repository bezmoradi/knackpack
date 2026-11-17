---
type: regex
arm: with-only
target: trace
# The reviewer's reply to the main session ends with its findings line, then
# its verdict line, which a push gate reads first. Only blank lines may follow
# the verdict before the reply ends: the JSON string's closing quote, the
# Agent result's agentId footer, or a notification's </result>. In the trace,
# a line break is the two characters \n.
pattern: 'knackpack-findings/1: critical=[0-9]+ high=[0-9]+ medium=[0-9]+ low=[0-9]+ blocking=[0-9]+(\\n|\s)+knackpack-verdict/1: (pass|block)(\\n|\s)*("|\\nagentId: |</result>)'
---
