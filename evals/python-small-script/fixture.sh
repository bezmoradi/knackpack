#!/bin/bash
# A repository that is just one standalone maintenance script and a README:
# prune_backups.py deletes .bak files older than N days from a folder, dry run
# by default. The change adds a --keep option to always keep the newest few.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p scripts

cat > scripts/prune_backups.py <<'PY'
#!/usr/bin/env python3
"""Delete backup files older than N days from a folder.

Dry run by default: it prints what it would delete. Pass --apply to delete.
"""

import argparse
import sys
import time
from pathlib import Path

BACKUP_SUFFIX = ".bak"


def find_old_backups(folder, max_age_days, now):
    cutoff = now - max_age_days * 86400
    old = []
    for path in sorted(folder.glob("*" + BACKUP_SUFFIX)):
        if path.is_file() and path.stat().st_mtime < cutoff:
            old.append(path)
    return old


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Prune old backup files.")
    parser.add_argument("folder", type=Path, help="folder holding the backups")
    parser.add_argument(
        "--days", type=int, default=30, help="delete backups older than this many days"
    )
    parser.add_argument(
        "--apply", action="store_true", help="delete the files instead of a dry run"
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if not args.folder.is_dir():
        print("not a folder: {}".format(args.folder), file=sys.stderr)
        return 2
    doomed = find_old_backups(args.folder, args.days, time.time())
    for path in doomed:
        if args.apply:
            path.unlink()
            print("deleted {}".format(path))
        else:
            print("would delete {}".format(path))
    if not args.apply:
        print(
            "dry run: {} file(s) would be deleted; pass --apply to delete".format(
                len(doomed)
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY

cat > README.md <<'MD'
# prune-backups

A standalone maintenance script. It deletes `*.bak` files older than `--days`
(default 30) from a folder. It does a dry run unless you pass `--apply`.

    python3 scripts/prune_backups.py /var/backups
    python3 scripts/prune_backups.py /var/backups --days 14 --apply
MD

git add -A
git commit -qm "Add the backup-pruning script"

cat > scripts/prune_backups.py <<'PY'
#!/usr/bin/env python3
"""Delete backup files older than N days from a folder.

Dry run by default: it prints what it would delete. Pass --apply to delete.
"""

import argparse
import sys
import time
from pathlib import Path

BACKUP_SUFFIX = ".bak"


def find_old_backups(folder, max_age_days, keep, now):
    cutoff = now - max_age_days * 86400
    backups = [p for p in folder.glob("*" + BACKUP_SUFFIX) if p.is_file()]
    # Newest first, so the first `keep` entries are the ones we always protect.
    backups.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    protected = set(backups[:keep]) if keep > 0 else set()
    doomed = [
        p for p in backups if p not in protected and p.stat().st_mtime < cutoff
    ]
    return sorted(doomed)


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="Prune old backup files.")
    parser.add_argument("folder", type=Path, help="folder holding the backups")
    parser.add_argument(
        "--days", type=int, default=30, help="delete backups older than this many days"
    )
    parser.add_argument(
        "--keep",
        type=int,
        default=0,
        help="always keep the newest N backups, even if older than --days",
    )
    parser.add_argument(
        "--apply", action="store_true", help="delete the files instead of a dry run"
    )
    return parser.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    if not args.folder.is_dir():
        print("not a folder: {}".format(args.folder), file=sys.stderr)
        return 2
    doomed = find_old_backups(args.folder, args.days, args.keep, time.time())
    for path in doomed:
        if args.apply:
            path.unlink()
            print("deleted {}".format(path))
        else:
            print("would delete {}".format(path))
    if not args.apply:
        print(
            "dry run: {} file(s) would be deleted; pass --apply to delete".format(
                len(doomed)
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
PY
