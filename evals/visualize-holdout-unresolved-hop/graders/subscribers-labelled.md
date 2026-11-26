---
type: regex
target: last_message
# The config-loaded handlers carry the label Inferred or Unknown, as a word
# on the same line as the handler, subscription or bus step it marks.
pattern: '\b(Inferred|Unknown)\b[^\n]{0,120}(refund_payment|release_stock|subscri|EVENTS_SUBSCRIPTIONS|[Hh]andler|publish|bus)|(refund_payment|release_stock|subscri|EVENTS_SUBSCRIPTIONS|[Hh]andler|publish|bus)[^\n]{0,120}\b(Inferred|Unknown)\b'
arm: with-only
---
