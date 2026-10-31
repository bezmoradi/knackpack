#!/bin/bash
# A small back-office web app repository with a GitHub bug form that asks for
# expected and actual behavior. Its remote points at a host that can't resolve
# (.invalid), so nothing can be published. Nothing is uncommitted; the user only
# asks for a ticket to be written.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
git remote add origin https://github.invalid/shop/web.git
mkdir -p .github/ISSUE_TEMPLATE

cat > README.md <<'EOF'
# shop web

The back-office web app the support team uses to look up and manage customer
accounts. The account list can be filtered by status and opens an account's
details page.
EOF

cat > .github/ISSUE_TEMPLATE/bug.yml <<'EOF'
name: Bug report
description: Something in the back office doesn't work as it should.
labels: ["bug"]
body:
  - type: textarea
    id: expected
    attributes:
      label: Expected behavior
      description: What should happen?
    validations:
      required: true
  - type: textarea
    id: actual
    attributes:
      label: Actual behavior
      description: What happens instead?
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to reproduce
      description: How to see the problem, if you know.
    validations:
      required: false
EOF

git add -A
git commit -qm "Back-office web app with a bug report form"
