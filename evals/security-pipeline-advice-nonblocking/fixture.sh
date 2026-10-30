#!/bin/bash
# A small Node storefront with no CI, committed, plus an uncommitted workflow
# that lints pull requests.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p src scripts

cat > package.json <<'EOF'
{
  "name": "shop",
  "version": "0.4.0",
  "private": true,
  "scripts": {
    "build": "node scripts/build.js",
    "test": "node --test",
    "lint": "node --check src/index.js && node --check scripts/build.js"
  }
}
EOF

cat > package-lock.json <<'EOF'
{
  "name": "shop",
  "version": "0.4.0",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "shop",
      "version": "0.4.0"
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

cat > README.md <<'EOF'
# shop

The storefront's static catalog page.

    npm ci
    npm run lint
    npm run build   # writes dist/
EOF

git add -A
git commit -qm "Add catalog page"

mkdir -p .github/workflows
cat > .github/workflows/lint.yml <<'EOF'
name: Lint

on:
  pull_request:

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: npm ci --ignore-scripts
      - run: npm run lint
EOF
