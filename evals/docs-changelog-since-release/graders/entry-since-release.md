---
type: llm
focus: { source: file, path: CHANGELOG.md }
---

This is a CLI's CHANGELOG.md after Claude was asked to add what changed since the last release. Release 1.4.0 (tagged v1.4.0) shipped with JSON export. Since then, three commits: CSV export was added; the next commit fixed the CSV header order, a bug the CSV commit itself had introduced, so no released version ever had it; and `export --out` was renamed to `--output`, with `--out` kept as an alias.
PASS if all three hold. First, a new entry (Unreleased or a version after 1.4.0) lists CSV export and the rename to --output, saying or implying that --out still works. Second, the new entry doesn't list the CSV header-order fix as a fix or change for users; folding it silently into the CSV export line passes. Third, the 1.4.0 entry still lists only JSON export under Added and the import blank-line fix under Fixed.
FAIL if the new entry lists the header-order fix as a fix for users, if CSV export or the rename is missing, if the rename is described as removing --out, or if anything was added to or changed in the 1.4.0 entry.
