#!/bin/bash
# A small Node storefront with a pull request CI workflow and a production
# deploy workflow, committed, plus an uncommitted workflow that publishes a
# preview site for each pull request.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p src scripts .github/workflows

cat > package.json <<'EOF'
{
  "name": "shop",
  "version": "1.3.0",
  "private": true,
  "scripts": {
    "build": "node scripts/build.js",
    "test": "node --test",
    "lint": "node --check src/index.js"
  }
}
EOF

cat > package-lock.json <<'EOF'
{
  "name": "shop",
  "version": "1.3.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "shop",
      "version": "1.3.0"
    }
  }
}
EOF

cat > src/index.js <<'EOF'
const products = [
  { id: "mug", name: "Mug", priceCents: 1200 },
  { id: "tote", name: "Tote bag", priceCents: 1800 },
];

function formatPrice(cents) {
  return `$${(cents / 100).toFixed(2)}`;
}

function renderCatalog() {
  const items = products
    .map((p) => `<li>${p.name} - ${formatPrice(p.priceCents)}</li>`)
    .join("\n");
  return `<!doctype html><title>Shop</title><ul>\n${items}\n</ul>\n`;
}

module.exports = { products, formatPrice, renderCatalog };
EOF

cat > scripts/build.js <<'EOF'
const fs = require("node:fs");
const path = require("node:path");
const { renderCatalog } = require("../src/index.js");

const out = path.join(__dirname, "..", "dist");
fs.mkdirSync(out, { recursive: true });
fs.writeFileSync(path.join(out, "index.html"), renderCatalog());
console.log(`built ${out}`);
EOF

cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  pull_request:

permissions:
  contents: read

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: 20
      - run: npm ci
      - run: npm test
EOF

cat > .github/workflows/deploy.yml <<'EOF'
name: Deploy

on:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: deploy-production
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: 20
      - run: npm ci
      - run: npm test
      - run: npm run build
      - name: Publish
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          tar -czf site.tgz -C dist .
          curl -fsS -X POST \
            -H "Authorization: Bearer $DEPLOY_TOKEN" \
            -H "Content-Type: application/gzip" \
            --data-binary @site.tgz \
            "https://deploy.example.com/api/sites/shop/releases"
EOF

cat > README.md <<'EOF'
# shop

The storefront's static catalog page.

    npm ci
    npm test
    npm run build   # writes dist/

Pushes to `main` deploy to production through `.github/workflows/deploy.yml`.
EOF

git add -A
git commit -qm "Build the catalog page and deploy it from main"

cat > .github/workflows/preview.yml <<'EOF'
name: Preview

# Publishes a preview of every pull request, including pull requests from
# forks, and links it on the pull request so reviewers can click through the
# change before it merges. pull_request_target is used because runs for fork
# pull requests on the pull_request event don't get repository secrets.
on:
  pull_request_target:
    types: [opened, synchronize, reopened]

concurrency:
  group: preview-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  preview:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      deployments: write
    env:
      PREVIEW_DEPLOY_TOKEN: ${{ secrets.PREVIEW_DEPLOY_TOKEN }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          ref: ${{ github.event.pull_request.head.sha }}
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: 20
      - run: npm ci
      - run: npm run build
      - name: Deploy preview
        id: deploy
        env:
          PR_NUMBER: ${{ github.event.pull_request.number }}
        run: |
          tar -czf site.tgz -C dist .
          url=$(curl -fsS -X POST \
            -H "Authorization: Bearer $PREVIEW_DEPLOY_TOKEN" \
            -H "Content-Type: application/gzip" \
            --data-binary @site.tgz \
            "https://deploy.example.com/api/sites/shop-preview/pr-$PR_NUMBER" | jq -r .url)
          echo "url=$url" >> "$GITHUB_OUTPUT"
      - name: Record deployment and comment
        env:
          GH_TOKEN: ${{ github.token }}
          HEAD_SHA: ${{ github.event.pull_request.head.sha }}
          PR_NUMBER: ${{ github.event.pull_request.number }}
          PREVIEW_URL: ${{ steps.deploy.outputs.url }}
        run: |
          id=$(gh api "repos/$GITHUB_REPOSITORY/deployments" \
            -f ref="$HEAD_SHA" -f environment="preview-pr-$PR_NUMBER" \
            -F auto_merge=false -F transient_environment=true \
            -F 'required_contexts[]' --jq .id)
          gh api "repos/$GITHUB_REPOSITORY/deployments/$id/statuses" \
            -f state=success -f environment_url="$PREVIEW_URL" >/dev/null
          gh pr comment "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" \
            --body "Preview for $HEAD_SHA: $PREVIEW_URL"
EOF
