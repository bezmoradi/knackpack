#!/bin/bash
# A small Python report tool whose page count drops the last partial page:
# 21 rows at 10 a page gives 2 pages, not 3. A plan for the fix is committed
# under docs/plans. The user asks only for a plan for a related change, so
# Execute plan must not start and nothing gets edited.
set -euo pipefail
git init -q
git config user.name "Sam Okafor"
git config user.email "sam@example.com"

cat > README.md <<'EOF'
# rowreport

Prints a paged report of the rows in a CSV file: `python3 report.py rows.csv`.
Each page holds `PER_PAGE` rows, set in `pages.py`.
EOF

cat > pages.py <<'EOF'
"""Splitting report rows into pages."""

PER_PAGE = 10


def page_count(total, per_page=PER_PAGE):
    """Return how many pages `total` rows need."""
    if total <= 0:
        return 0
    return total // per_page


def page(rows, number, per_page=PER_PAGE):
    """Return the rows on page `number`, counting from 1."""
    start = (number - 1) * per_page
    return rows[start:start + per_page]
EOF

cat > report.py <<'EOF'
import csv
import sys

from pages import page, page_count


def main(path):
    with open(path, newline="") as f:
        rows = list(csv.reader(f))
    pages = page_count(len(rows))
    for n in range(1, pages + 1):
        print(f"--- page {n} of {pages} ---")
        for row in page(rows, n):
            print(", ".join(row))


if __name__ == "__main__":
    main(sys.argv[1])
EOF

mkdir -p docs/plans
cat > docs/plans/last-page.md <<'EOF'
# Plan: show the last partial page

Baseline: the commit that added this plan.

## Readiness
READY TO IMPLEMENT.

## Objective and scope
A report whose row count isn't a multiple of PER_PAGE leaves out its last
rows: 21 rows at 10 a page print 2 pages. Every row must be printed.
Out of scope: page size, output format.

## Work packages

### PLAN-01: count the partial last page
- Locations: pages.py, page_count.
- Ownership: pages.py.
- Dependencies: none.
- Work: round the page count up, so 21 rows at 10 a page give 3 pages,
  20 give 2, and 0 give 0.
- Validation: `python3 -c "from pages import page_count as c; print(c(21), c(20), c(0), c(1))"`
  prints `3 2 0 1`.
- Completion criteria: the validation prints `3 2 0 1`, and report.py is
  unchanged.
- Status: not started.

## Requirement coverage
| Requirement | Work package | Verification |
|---|---|---|
| Every row is printed | PLAN-01 | the validation command |

## First executable step
PLAN-01.
EOF

git add -A
git commit -qm "Report tool, and a plan for the last-page fix"
