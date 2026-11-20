---
type: regex
arm: with-only
target: last_message
flags: i
# (*Scheduler).Plan is unchanged since the earlier report, where it was F2, so
# its findings table row ends with Earlier F2, then its State.
pattern: '\|\s*F\d+\s*\|[^\n]*(scheduler\.go|Plan)[^\n]*\|\s*F2\s*\|\s*(unchanged|updated-better|updated-worse|present-at-baseline|new-since-baseline)\s*\|'
---
