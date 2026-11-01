#!/bin/bash
# A small CLI with a changelog whose 1.4.0 entry has shipped, and three
# commits since: CSV export, a fix for a bug the CSV commit itself introduced,
# and a renamed flag that keeps its old name as an alias.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p ledgerctl
cat > README.md <<'MD'
# ledgerctl

Export a ledger: `ledgerctl export --format json --out ledger.json`.
MD
cat > CHANGELOG.md <<'MD'
# Changelog

## 1.4.0 - 2026-09-30

### Added

- `ledgerctl export --format json` writes the ledger as JSON.

### Fixed

- `ledgerctl import` no longer stops at the first blank line.
MD
cat > ledgerctl/export.py <<'PY'
import json


def export(rows, fmt, out):
    if fmt != "json":
        raise SystemExit(f"unknown format: {fmt}")
    with open(out, "w") as f:
        json.dump(rows, f)
PY
git add -A
git commit -q -m "Release 1.4.0"
git tag v1.4.0

cat > ledgerctl/export.py <<'PY'
import csv
import json

COLUMNS = ["amount", "date", "account"]


def export(rows, fmt, out):
    if fmt == "json":
        with open(out, "w") as f:
            json.dump(rows, f)
    elif fmt == "csv":
        with open(out, "w", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(COLUMNS)
            for row in rows:
                writer.writerow([row["date"], row["account"], row["amount"]])
    else:
        raise SystemExit(f"unknown format: {fmt}")
PY
git commit -q -am "Add CSV export (ledgerctl export --format csv)"

sed -i.bak 's/COLUMNS = \["amount", "date", "account"\]/COLUMNS = ["date", "account", "amount"]/' ledgerctl/export.py
rm -f ledgerctl/export.py.bak
git commit -q -am "Fix CSV header order: the header didn't match the columns written in the previous commit"

cat > ledgerctl/cli.py <<'PY'
import argparse


def parser():
    p = argparse.ArgumentParser(prog="ledgerctl")
    sub = p.add_subparsers(dest="command", required=True)
    export = sub.add_parser("export")
    export.add_argument("--format", choices=["json", "csv"], default="json")
    # --out still works, so existing scripts keep running.
    export.add_argument("--output", "--out", dest="output", required=True)
    return p
PY
sed -i.bak 's/--out ledger.json/--output ledger.json/' README.md
rm -f README.md.bak
git add -A
git commit -q -m "Rename export --out to --output, keeping --out as an alias"
