---
type: regex
target: { source: file, path: app/export.py }
# The fix leaves the unrelated helper, its TODO and its float arithmetic as
# they were.
pattern: 'def fmt_total\(cents\):  # TODO: rename to format_total and switch the export to Decimal\n    return "%\.2f" % \(cents / 100\)'
arm: both
---
