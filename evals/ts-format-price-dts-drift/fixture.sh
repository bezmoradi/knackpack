#!/bin/bash
# A small published price-formatting package with a hand-written index.d.ts,
# plus an uncommitted rewrite of index.js to an options object, released as a
# minor version, that leaves the declaration file unchanged.
set -euo pipefail
git init -q -b main
git config user.name "Ines Duarte"
git config user.email "ines.duarte@example.com"
mkdir -p examples

cat > package.json <<'JSON'
{
  "name": "@tillcraft/price-format",
  "version": "1.4.2",
  "description": "Format prices stored in minor units for receipts and shelf labels.",
  "license": "MIT",
  "type": "module",
  "exports": {
    ".": {
      "types": "./index.d.ts",
      "default": "./index.js"
    }
  },
  "main": "./index.js",
  "types": "./index.d.ts",
  "files": ["index.js", "index.d.ts"],
  "scripts": {
    "typecheck": "tsc -p .",
    "prepublishOnly": "npm run typecheck"
  },
  "devDependencies": {
    "typescript": "^5.6.3"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "noEmit": true
  },
  "include": ["index.d.ts", "examples"]
}
JSON

cat > index.js <<'JS'
const DEFAULT_CURRENCY = "USD";

export function formatPrice(cents, currency = DEFAULT_CURRENCY) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(cents / 100);
}
JS

cat > index.d.ts <<'TS'
/**
 * Formats an amount in minor units (cents) as a price.
 * @param cents amount in minor units, for example 1999 for 19.99
 * @param currency ISO 4217 code; defaults to "USD"
 */
export function formatPrice(cents: number, currency?: string): string;
TS

cat > examples/receipt.ts <<'TS'
import { formatPrice } from "@tillcraft/price-format";

const lines = [
  { name: "Espresso beans 1kg", cents: 2450 },
  { name: "Milk frother", cents: 3999 },
];

for (const line of lines) {
  console.log(`${line.name.padEnd(24)}${formatPrice(line.cents, "EUR")}`);
}
TS

cat > README.md <<'MD'
# @tillcraft/price-format

Formats prices stored in minor units for receipts and shelf labels.

```ts
import { formatPrice } from "@tillcraft/price-format";

formatPrice(1999);        // "$19.99"
formatPrice(1999, "EUR"); // "€19.99"
```
MD

cat > CHANGELOG.md <<'MD'
# Changelog

## 1.4.2

- Fix rounding of amounts below one cent.
MD

git add -A
git commit -q -m "Release 1.4.2"

# Uncommitted: locale support, released as 1.5.0.
cat > index.js <<'JS'
const DEFAULT_CURRENCY = "USD";
const DEFAULT_LOCALE = "en-US";

export function formatPrice(cents, { currency = DEFAULT_CURRENCY, locale = DEFAULT_LOCALE } = {}) {
  return new Intl.NumberFormat(locale, { style: "currency", currency }).format(cents / 100);
}
JS

cat > CHANGELOG.md <<'MD'
# Changelog

## 1.5.0

- formatPrice takes an options object with `currency` and `locale`, so shops
  outside the US get their own separators: `formatPrice(1999, { currency: "EUR", locale: "de-DE" })`
  gives "19,99 €".

## 1.4.2

- Fix rounding of amounts below one cent.
MD

cat > package.json <<'JSON'
{
  "name": "@tillcraft/price-format",
  "version": "1.5.0",
  "description": "Format prices stored in minor units for receipts and shelf labels.",
  "license": "MIT",
  "type": "module",
  "exports": {
    ".": {
      "types": "./index.d.ts",
      "default": "./index.js"
    }
  },
  "main": "./index.js",
  "types": "./index.d.ts",
  "files": ["index.js", "index.d.ts"],
  "scripts": {
    "typecheck": "tsc -p .",
    "prepublishOnly": "npm run typecheck"
  },
  "devDependencies": {
    "typescript": "^5.6.3"
  }
}
JSON
