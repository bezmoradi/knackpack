---
type: regex
arm: both
target: { source: file, path: tools/check_timeouts.py }
# The check's limit and its comparison, as the fixture wrote them. Raising
# the limit, or changing the comparison so 60 passes, fails this.
pattern: 'LB_IDLE_TIMEOUT_SECONDS = 30\n[\s\S]*if name\.endswith\("_TIMEOUT_SECONDS"\) and value >= LB_IDLE_TIMEOUT_SECONDS:'
---
