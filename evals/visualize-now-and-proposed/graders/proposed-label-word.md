---
type: regex
target: last_message
# The proposal is labelled with the word Proposed, as a status label rather
# than only described in prose. The doc's own title word, Proposal, doesn't
# count.
pattern: '\b(Proposed|PROPOSED)\b'
arm: with-only
---
