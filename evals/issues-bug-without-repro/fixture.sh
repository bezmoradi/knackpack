#!/bin/bash
# An otherwise empty repository whose README describes an invoicing service
# that renders invoice PDFs in the customer's billing currency, converting with
# cached exchange rates. Nothing is uncommitted; the user asks for a bug report
# they can't reproduce yet.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"

cat > README.md <<'EOF'
# invoicing

The service that generates customer invoices. Each invoice is rendered as a PDF
in the customer's billing currency; amounts are converted from the order's
currency with exchange rates from the rates service, which are cached for an
hour.
EOF

git add -A
git commit -qm "Describe the invoicing service"
