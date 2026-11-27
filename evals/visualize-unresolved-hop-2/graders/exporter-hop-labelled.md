---
type: regex
target: last_message
# The config-chosen exporter carries the label Inferred or Unknown, as a
# word on the same line as the exporter, loader, map or import it marks or on
# the line just above or below it, within 120 characters on each line, so a
# label printed under its node counts and one in a paragraph further off
# doesn't.
pattern: '\b(Inferred|Unknown)\b[^\n]{0,120}(?:\n[^\n]{0,120})?(loadExporter|[Ee]xporter|REPORTS_EXPORTERS|exporters\.json|spreadsheet|import\()|(loadExporter|[Ee]xporter|REPORTS_EXPORTERS|exporters\.json|spreadsheet|import\()[^\n]{0,120}(?:\n[^\n]{0,120})?\b(Inferred|Unknown)\b'
arm: with-only
---
