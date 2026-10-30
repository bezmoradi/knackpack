#!/bin/bash
# A small Node storefront with one old CI workflow, committed, plus an
# uncommitted change that replaces it with separate build, release and
# labeling workflows and an AWS deploy role trust policy.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p src scripts .github/workflows

cat > package.json <<'EOF'
{
  "name": "shop",
  "version": "2.0.0",
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
  "version": "2.0.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "shop",
      "version": "2.0.0"
    }
  }
}
EOF

cat > src/index.js <<'EOF'
const products = [
  { id: "mug", name: "Mug", priceCents: 1200 },
  { id: "tote", name: "Tote bag", priceCents: 1800 },
];

function renderCatalog() {
  const items = products.map((p) => `<li>${p.name} $${(p.priceCents / 100).toFixed(2)}</li>`);
  return `<!doctype html><title>Shop</title><ul>\n${items.join("\n")}\n</ul>\n`;
}

module.exports = { products, renderCatalog };
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

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
      - run: npm install
      - run: npm test
EOF

cat > README.md <<'EOF'
# shop

The storefront's static catalog page, served from S3.

    npm ci
    npm test
    npm run build   # writes dist/
EOF

git add -A
git commit -qm "Add catalog page and CI"

rm .github/workflows/ci.yml
mkdir -p infra

cat > .github/workflows/build.yml <<'EOF'
name: Build

on:
  pull_request:

permissions:
  contents: read

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          persist-credentials: false
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: 20
      - run: npm ci --ignore-scripts
      - run: npm test
      - run: npm run build
      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
        with:
          name: site
          path: dist/
          retention-days: 7
EOF

cat > .github/workflows/release.yml <<'EOF'
name: Release

on:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: release-production
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      sha256: ${{ steps.digest.outputs.sha256 }}
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
        with:
          persist-credentials: false
      - uses: actions/setup-node@49933ea5288caeca8642d1e84afbd3f7d6820020 # v4.4.0
        with:
          node-version: 20
      - run: npm ci --ignore-scripts
      - run: npm test
      - run: npm run build
      - run: tar -czf site.tgz -C dist .
      - id: digest
        run: echo "sha256=$(sha256sum site.tgz | cut -d ' ' -f 1)" >> "$GITHUB_OUTPUT"
      - uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02 # v4.6.2
        with:
          name: site-release
          path: site.tgz
          if-no-files-found: error
          retention-days: 30

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/download-artifact@d3f86a106a0bac45b974a628896c90dbdf5c8093 # v4.3.0
        with:
          name: site-release
      - name: Verify artifact
        env:
          EXPECTED_SHA256: ${{ needs.build.outputs.sha256 }}
        run: |
          test -n "$EXPECTED_SHA256"
          echo "$EXPECTED_SHA256  site.tgz" | sha256sum --check --strict
      - uses: aws-actions/configure-aws-credentials@b47578312673ae6fa5b5096b330d9fbac3d116df # v4.2.1
        with:
          role-to-assume: arn:aws:iam::123456789012:role/shop-deploy
          aws-region: us-east-1
      - name: Deploy
        run: |
          mkdir site
          tar -xzf site.tgz -C site
          aws s3 sync site/ s3://shop-site-production/ --delete
EOF

cat > .github/workflows/labeler.yml <<'EOF'
name: Label pull requests

on:
  pull_request_target:
    types: [opened, synchronize, reopened]

permissions:
  contents: read
  pull-requests: write

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@8558fd74291d67161a8a78ce36a881fa63b766a9 # v5.0.0
        with:
          sync-labels: true
EOF

cat > .github/labeler.yml <<'EOF'
ci:
  - changed-files:
      - any-glob-to-any-file: ".github/**"
infra:
  - changed-files:
      - any-glob-to-any-file: "infra/**"
storefront:
  - changed-files:
      - any-glob-to-any-file: ["src/**", "scripts/**"]
docs:
  - changed-files:
      - any-glob-to-any-file: "**/*.md"
EOF

cat > infra/deploy-role-trust.json <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GitHubActionsProductionDeploy",
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:example-org/shop:environment:production"
        }
      }
    }
  ]
}
EOF
