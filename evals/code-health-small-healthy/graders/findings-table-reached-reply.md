---
type: regex
arm: with-only
target: last_message
# The reply carries the reviewer's findings table, by its header row, or the
# protocol's "No findings." in its place. Without this, a reply that only
# summarizes the report, such as "the reviewer found two Medium issues", has
# no table row for nothing-medium-or-higher to find, and that grader passes.
pattern: '\|\s*ID\s*\|\s*Severity\s*\||No findings\.'
---
