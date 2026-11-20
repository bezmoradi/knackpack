---
type: regex
arm: with-only
target: last_message
match: not_contains
flags: i
# Nothing written after the tag is long or deeply nested, and every other
# finding already held at v1.4.0, so no findings table row may have the State
# new-since-baseline.
pattern: '\|\s*F\d+\s*\|[^\n]*\|\s*new-since-baseline\s*\|'
---
