---
type: regex
arm: with-only
target: trace
# Without the count command, the reviewer still writes a finding line for its
# first finding, with the keys in the command's order.
pattern: 'knackpack-finding/1 \{\\?"id\\?":\\?"F1\\?",\\?"severity\\?":\\?"(critical|high|medium|low)\\?",\\?"blocking\\?":(true|false)(,\\?"path\\?":\\?"app/orders\.py\\?"(,\\?"line\\?":[0-9]+)?)?'
---
