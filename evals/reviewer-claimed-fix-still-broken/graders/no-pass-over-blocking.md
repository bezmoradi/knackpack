---
type: regex
arm: both
target: trace
match: not_contains
# A findings line that counts a blocking finding must never come with
# knackpack-verdict/1: pass, since a push gate would let the change through.
pattern: 'blocking=[1-9][0-9]*(\\n|\s)+knackpack-verdict/1: pass'
---
