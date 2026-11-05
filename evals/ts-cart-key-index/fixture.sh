#!/bin/bash
# An abandoned-cart report, plus an uncommitted per-SKU breakdown that adds to
# Record<string, number> entries that don't exist yet.
set -euo pipefail
git init -q -b main
git config user.name "Priya Natarajan"
git config user.email "priya.natarajan@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "cart-insights",
  "version": "1.4.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "report": "node dist/main.js"
  },
  "devDependencies": {
    "@types/node": "^24.3.0",
    "typescript": "^5.9.3"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "rootDir": "src",
    "outDir": "dist",
    "types": ["node"]
  },
  "include": ["src"]
}
JSON
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > src/types.ts <<'TS'
export interface CartLine {
  sku: string;
  name: string;
  quantity: number;
  unitPriceCents: number;
}

export interface Cart {
  id: string;
  customerId: string;
  updatedAt: Date;
  checkedOut: boolean;
  lines: CartLine[];
}
TS
cat > src/carts.ts <<'TS'
import type { Cart } from "./types.js";

export function abandonedCarts(carts: readonly Cart[], now: Date, idleMinutes = 60): Cart[] {
  const cutoff = now.getTime() - idleMinutes * 60_000;
  return carts.filter(
    (cart) => !cart.checkedOut && cart.lines.length > 0 && cart.updatedAt.getTime() < cutoff,
  );
}

export function cartValueCents(cart: Cart): number {
  return cart.lines.reduce((sum, line) => sum + line.quantity * line.unitPriceCents, 0);
}
TS
cat > src/report.ts <<'TS'
import { cartValueCents } from "./carts.js";
import type { Cart } from "./types.js";

export interface AbandonedReport {
  cartCount: number;
  totalValueCents: number;
}

export function buildAbandonedReport(carts: readonly Cart[]): AbandonedReport {
  let totalValueCents = 0;
  for (const cart of carts) {
    totalValueCents += cartValueCents(cart);
  }
  return { cartCount: carts.length, totalValueCents };
}
TS
cat > src/dashboard.ts <<'TS'
import type { AbandonedReport } from "./report.js";

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

export function renderDashboard(report: AbandonedReport): string {
  return [
    "Abandoned carts (last 24h)",
    `  Carts:          ${report.cartCount}`,
    `  Value at risk:  ${money.format(report.totalValueCents / 100)}`,
  ].join("\n");
}
TS
cat > src/main.ts <<'TS'
import { abandonedCarts } from "./carts.js";
import { renderDashboard } from "./dashboard.js";
import { buildAbandonedReport } from "./report.js";
import { sampleCarts } from "./sample-carts.js";

const now = new Date("2026-03-02T12:00:00Z");
const report = buildAbandonedReport(abandonedCarts(sampleCarts, now));
console.log(renderDashboard(report));
TS
cat > src/sample-carts.ts <<'TS'
import type { Cart } from "./types.js";

// Local data for `npm run report`; production reads carts from the orders API.
export const sampleCarts: Cart[] = [
  {
    id: "c-1001",
    customerId: "u-77",
    updatedAt: new Date("2026-03-02T08:15:00Z"),
    checkedOut: false,
    lines: [
      { sku: "MUG-BLU", name: "Blue mug", quantity: 2, unitPriceCents: 1400 },
      { sku: "TEA-EARL", name: "Earl Grey, 100g", quantity: 1, unitPriceCents: 900 },
    ],
  },
  {
    id: "c-1002",
    customerId: "u-81",
    updatedAt: new Date("2026-03-02T09:40:00Z"),
    checkedOut: false,
    lines: [{ sku: "MUG-BLU", name: "Blue mug", quantity: 1, unitPriceCents: 1400 }],
  },
  {
    id: "c-1003",
    customerId: "u-90",
    updatedAt: new Date("2026-03-02T11:50:00Z"),
    checkedOut: false,
    lines: [{ sku: "KETTLE-1", name: "Gooseneck kettle", quantity: 1, unitPriceCents: 5200 }],
  },
  {
    id: "c-1004",
    customerId: "u-93",
    updatedAt: new Date("2026-03-01T19:05:00Z"),
    checkedOut: true,
    lines: [{ sku: "TEA-EARL", name: "Earl Grey, 100g", quantity: 3, unitPriceCents: 900 }],
  },
];
TS
git add -A
git commit -q -m "Abandoned cart dashboard with count and value at risk"

# Uncommitted: break abandoned quantities down by SKU and list the top products.
cat > src/report.ts <<'TS'
import { cartValueCents } from "./carts.js";
import type { Cart } from "./types.js";

export interface AbandonedReport {
  cartCount: number;
  totalValueCents: number;
  quantityBySku: Record<string, number>;
}

export function buildAbandonedReport(carts: readonly Cart[]): AbandonedReport {
  let totalValueCents = 0;
  const quantityBySku: Record<string, number> = {};
  for (const cart of carts) {
    totalValueCents += cartValueCents(cart);
    for (const line of cart.lines) {
      quantityBySku[line.sku] += line.quantity;
    }
  }
  return { cartCount: carts.length, totalValueCents, quantityBySku };
}

export function topSkus(report: AbandonedReport, limit = 5): Array<[sku: string, quantity: number]> {
  return Object.entries(report.quantityBySku)
    .sort(([, a], [, b]) => b - a)
    .slice(0, limit);
}
TS
cat > src/dashboard.ts <<'TS'
import { topSkus, type AbandonedReport } from "./report.js";

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });

export function renderDashboard(report: AbandonedReport): string {
  const lines = [
    "Abandoned carts (last 24h)",
    `  Carts:          ${report.cartCount}`,
    `  Value at risk:  ${money.format(report.totalValueCents / 100)}`,
    "",
    "Most abandoned products",
  ];
  for (const [sku, quantity] of topSkus(report)) {
    lines.push(`  ${sku.padEnd(12)} ${quantity} units`);
  }
  return lines.join("\n");
}
TS
