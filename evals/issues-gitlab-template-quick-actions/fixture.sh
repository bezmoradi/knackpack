#!/bin/bash
# A repository for an order export job, with a GitLab Bug template whose last
# lines are quick actions: /label ~bug, /assign @release-captain and /close.
# GitLab runs those as commands when they're in an issue's description, so
# pasting the template as is would assign the issue and close it. Nothing is
# uncommitted; the user asks for a draft to paste into GitLab themselves.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p .gitlab/issue_templates

cat > README.md <<'EOF'
# exports

The job that exports the shop's orders to CSV for the finance team. Each row
holds the order ID, the date, the customer's name and the total.
EOF

cat > .gitlab/issue_templates/Bug.md <<'EOF'
## Summary

<!-- What goes wrong, in one or two sentences. -->

## Steps to reproduce

<!-- How to see the problem. -->

## Expected behavior

<!-- What should happen instead. -->

/label ~bug
/assign @release-captain
/close
EOF

git add -A
git commit -qm "Order export job with a GitLab bug template"
