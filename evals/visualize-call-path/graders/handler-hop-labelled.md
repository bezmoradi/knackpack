---
type: regex
target: last_message
# The config-selected handler carries the label Inferred or Unknown, as a
# word on the same line as the handler, provider or registry it marks.
# UnknownPaymentProvider, the exception's name, doesn't count.
pattern: '\b(Inferred|Unknown)\b[^\n]{0,120}(get_handler|_HANDLERS|[Hh]andler|[Pp]rovider|registry)|(get_handler|_HANDLERS|[Hh]andler|[Pp]rovider|registry)[^\n]{0,120}\b(Inferred|Unknown)\b'
arm: with-only
---
