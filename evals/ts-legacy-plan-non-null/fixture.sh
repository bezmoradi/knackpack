#!/bin/bash
# A subscription billing job for a project-planning SaaS, plus an uncommitted
# change that looks each account's plan up in the on-sale plan list with a non-null assertion.
set -euo pipefail
git init -q -b main
git config user.name "Lena Hoffmann"
git config user.email "lena.hoffmann@example.com"
mkdir -p src/billing db/migrations

cat > package.json <<'JSON'
{
  "name": "planboard-billing",
  "version": "3.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "invoices:monthly": "node dist/billing/runMonthly.js"
  },
  "devDependencies": {
    "typescript": "~5.9.2"
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
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > db/migrations/0011_accounts.sql <<'SQL'
CREATE TABLE accounts (
  id            text PRIMARY KEY,
  name          text NOT NULL,
  plan_id       text NOT NULL,
  seats         integer NOT NULL CHECK (seats > 0),
  seat_price_cents integer NOT NULL
);
SQL

cat > db/migrations/0012_retire_legacy_plans.sql <<'SQL'
-- Stop selling the 2021 plans. Accounts already on pro-2021 or agency-2021
-- stay on them (grandfathered) until they choose a new plan; their seat price
-- is frozen in accounts.seat_price_cents.
UPDATE accounts SET seat_price_cents = 900  WHERE plan_id = 'pro-2021';
UPDATE accounts SET seat_price_cents = 1400 WHERE plan_id = 'agency-2021';
SQL

cat > src/billing/plans.ts <<'TS'
export interface Plan {
  id: string;
  name: string;
  monthlyPrice: number; // per seat, in cents
}

// Plans currently on sale.
export const PLANS: readonly Plan[] = [
  { id: "starter", name: "Starter", monthlyPrice: 600 },
  { id: "team", name: "Team", monthlyPrice: 1200 },
  { id: "business", name: "Business", monthlyPrice: 2000 },
];
TS

cat > src/billing/accounts.ts <<'TS'
export interface Account {
  id: string;
  name: string;
  planId: string;
  seats: number;
  seatPriceCents: number;
}

export interface Invoice {
  accountId: string;
  description: string;
  amountCents: number;
}
TS

cat > src/billing/invoiceJob.ts <<'TS'
import type { Account, Invoice } from "./accounts.js";

export function buildInvoice(account: Account): Invoice {
  return {
    accountId: account.id,
    description: `${account.seats} seats`,
    amountCents: account.seats * account.seatPriceCents,
  };
}

export function runMonthlyInvoices(accounts: Account[], send: (invoice: Invoice) => void): void {
  for (const account of accounts) {
    send(buildInvoice(account));
  }
}
TS

git add -A
git commit -q -m "Monthly invoice job"

# Uncommitted: price invoices from the plan list so a price change needs no data migration.
cat > src/billing/invoiceJob.ts <<'TS'
import type { Account, Invoice } from "./accounts.js";
import { PLANS } from "./plans.js";

export function buildInvoice(account: Account): Invoice {
  const plan = PLANS.find((p) => p.id === account.planId)!;
  return {
    accountId: account.id,
    description: `${plan.name} plan, ${account.seats} seats`,
    amountCents: account.seats * plan.monthlyPrice,
  };
}

export function runMonthlyInvoices(accounts: Account[], send: (invoice: Invoice) => void): void {
  for (const account of accounts) {
    send(buildInvoice(account));
  }
}
TS
