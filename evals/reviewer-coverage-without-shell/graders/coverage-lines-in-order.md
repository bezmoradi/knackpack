---
type: regex
arm: with-only
target: trace
# Without a shell, the reviewer's reply still has a coverage line for REQ-01, then one for REQ-02,
# then any finding lines, then the findings line and the verdict line, with
# only blank lines after it before the reply ends. In the trace a line break
# is the two characters \n and a quote is \", so a line's text is matched as
# characters that aren't a backslash, or a backslash not followed by n.
pattern: 'knackpack-coverage/1 ([^\\\n]|\\[^n])*REQ-01([^\\\n]|\\[^n])*(\\n|\s)+knackpack-coverage/1 ([^\\\n]|\\[^n])*REQ-02([^\\\n]|\\[^n])*(\\n|\s)+(knackpack-finding/1 ([^\\\n]|\\[^n])*(\\n|\s)+)*knackpack-findings/1: critical=[0-9]+ high=[0-9]+ medium=[0-9]+ low=[0-9]+ blocking=[0-9]+(\\n|\s)+knackpack-verdict/1: (pass|block)(\\n|\s)*("|\\nagentId: |</result>)'
---
