---
type: regex
arm: with-only
target: last_message
# The blocking question, by its ID. A reply that stops without saying which
# question blocks, or that names only Q-01, fails this.
pattern: '\bQ-02\b'
---
