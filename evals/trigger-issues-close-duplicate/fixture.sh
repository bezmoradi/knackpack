#!/bin/bash
# A small web app repository whose remote points at a host that can't resolve
# (.invalid), so no issue can be created, closed or commented on.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
git remote add origin https://github.invalid/shop/web.git

cat > README.md <<'EOF'
# shop web

The back-office web app the support team uses to look up customer accounts.
Bugs and requests are tracked in this repository's GitHub issues.
EOF

git add -A
git commit -qm "Back-office web app"
