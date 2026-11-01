---
type: regex
target: { source: file, path: docs/restore.md }
pattern: 'make restore[^\n]*BACKUP_ID=[^\n]*CONFIRM=yes|make restore[^\n]*CONFIRM=yes[^\n]*BACKUP_ID=|BACKUP_ID=[^\n]*make restore[^\n]*CONFIRM=yes|BACKUP_ID=[^\n]*CONFIRM=yes[^\n]*make restore|CONFIRM=yes[^\n]*make restore[^\n]*BACKUP_ID=|CONFIRM=yes[^\n]*BACKUP_ID=[^\n]*make restore'
---
