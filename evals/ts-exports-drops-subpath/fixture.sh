#!/bin/bash
# An npm workspace where the storefront imports @acme/ui-kit/tokens.js, plus an
# uncommitted exports map in ui-kit that lists only ".". After the commit it
# creates the node_modules symlink npm install makes for a workspace package
# (ignored by git), so node and tsc resolve @acme/ui-kit as they would locally.
set -euo pipefail
git init -q -b main
git config user.name "Ines Carvalho"
git config user.email "ines.carvalho@example.com"
mkdir -p packages/ui-kit packages/storefront/src
cat > package.json <<'JSON'
{
  "name": "shop-monorepo",
  "private": true,
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "build": "npm run build --workspaces --if-present"
  },
  "devDependencies": {
    "@types/node": "^24.3.0",
    "typescript": "^5.9.3"
  }
}
JSON
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > tsconfig.base.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "declaration": true,
    "skipLibCheck": false
  }
}
JSON
cat > packages/ui-kit/package.json <<'JSON'
{
  "name": "@acme/ui-kit",
  "version": "3.2.0",
  "description": "Design tokens and class helpers shared by the shop's front ends.",
  "type": "module",
  "main": "index.js",
  "types": "index.d.ts",
  "files": [
    "index.js",
    "index.d.ts",
    "tokens.js",
    "tokens.d.ts"
  ]
}
JSON
cat > packages/ui-kit/README.md <<'MD'
# @acme/ui-kit

Class helpers and design tokens for the shop's front ends.

```ts
import { buttonClass } from "@acme/ui-kit";
import { colors, spacing } from "@acme/ui-kit/tokens.js";
```

Import tokens from `@acme/ui-kit/tokens.js` so code that only needs colors or
spacing doesn't pull in the class helpers.
MD
cat > packages/ui-kit/tokens.js <<'JS'
export const colors = {
  brand: "#1d4ed8",
  brandContrast: "#ffffff",
  danger: "#b91c1c",
  surface: "#f8fafc",
};

export const spacing = {
  xs: "4px",
  sm: "8px",
  md: "16px",
  lg: "24px",
};
JS
cat > packages/ui-kit/tokens.d.ts <<'TS'
export declare const colors: {
  readonly brand: string;
  readonly brandContrast: string;
  readonly danger: string;
  readonly surface: string;
};

export declare const spacing: {
  readonly xs: string;
  readonly sm: string;
  readonly md: string;
  readonly lg: string;
};
TS
cat > packages/ui-kit/index.js <<'JS'
const variants = new Set(["primary", "secondary", "danger"]);

export function buttonClass(variant = "primary", size = "md") {
  if (!variants.has(variant)) throw new Error(`Unknown button variant: ${variant}`);
  return `uk-btn uk-btn--${variant} uk-btn--${size}`;
}
JS
cat > packages/ui-kit/index.d.ts <<'TS'
export type ButtonVariant = "primary" | "secondary" | "danger";
export type ButtonSize = "sm" | "md" | "lg";

export declare function buttonClass(variant?: ButtonVariant, size?: ButtonSize): string;
TS
cat > packages/storefront/package.json <<'JSON'
{
  "name": "@acme/storefront",
  "version": "0.9.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "theme": "node dist/print-theme.js"
  },
  "dependencies": {
    "@acme/ui-kit": "^3.2.0"
  }
}
JSON
cat > packages/storefront/tsconfig.json <<'JSON'
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "rootDir": "src",
    "outDir": "dist",
    "lib": ["ES2022"],
    "types": ["node"]
  },
  "include": ["src"]
}
JSON
cat > packages/storefront/src/theme.ts <<'TS'
import { colors, spacing } from "@acme/ui-kit/tokens.js";

export function themeVariables(): string {
  return [
    `--color-brand: ${colors.brand};`,
    `--color-on-brand: ${colors.brandContrast};`,
    `--color-surface: ${colors.surface};`,
    `--gap: ${spacing.md};`,
  ].join("\n");
}
TS
cat > packages/storefront/src/checkout-button.ts <<'TS'
import { buttonClass } from "@acme/ui-kit";

export function checkoutButtonHtml(itemCount: number): string {
  const label = itemCount === 1 ? "Check out 1 item" : `Check out ${itemCount} items`;
  return `<button class="${buttonClass("primary", "lg")}">${label}</button>`;
}
TS
cat > packages/storefront/src/print-theme.ts <<'TS'
import { checkoutButtonHtml } from "./checkout-button.js";
import { themeVariables } from "./theme.js";

process.stdout.write(`:root {\n${themeVariables()}\n}\n${checkoutButtonHtml(3)}\n`);
TS
git add -A
git commit -q -m "Storefront theme script reads ui-kit tokens"

# What `npm install` leaves for a workspace package.
mkdir -p node_modules/@acme
ln -s ../../packages/ui-kit node_modules/@acme/ui-kit
ln -s ../../packages/storefront node_modules/@acme/storefront

# Uncommitted: an exports map and a minor version for ui-kit.
cat > packages/ui-kit/package.json <<'JSON'
{
  "name": "@acme/ui-kit",
  "version": "3.3.0",
  "description": "Design tokens and class helpers shared by the shop's front ends.",
  "type": "module",
  "main": "index.js",
  "types": "index.d.ts",
  "exports": {
    ".": {
      "types": "./index.d.ts",
      "default": "./index.js"
    }
  },
  "sideEffects": false,
  "files": [
    "index.js",
    "index.d.ts",
    "tokens.js",
    "tokens.d.ts"
  ]
}
JSON
cat > packages/ui-kit/CHANGELOG.md <<'MD'
# Changelog

## 3.3.0

- Add an `exports` map so Node and bundlers resolve the same entry point, and
  mark the package free of side effects for tree shaking.
MD
