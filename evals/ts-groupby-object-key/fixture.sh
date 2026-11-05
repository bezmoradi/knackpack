#!/bin/bash
# An accounts-receivable service with a shared groupBy helper, plus an
# uncommitted overdue-reminder job that groups invoices by an object-valued key.
set -euo pipefail
git init -q -b main
git config user.name "Ingrid Solberg"
git config user.email "ingrid.solberg@example.com"
mkdir -p src/lib src/invoices src/reminders

cat > package.json <<'JSON'
{
  "name": "receivables",
  "version": "2.0.3",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "reminders": "node dist/reminders/overdueReminders.js"
  },
  "devDependencies": {
    "typescript": "^5.9.3"
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

cat > src/lib/groupBy.ts <<'TS'
// Groups items into buckets by the value of one of their properties.
export function groupBy<T, K extends keyof T>(items: T[], key: K): Record<string, T[]> {
  const groups: Record<string, T[]> = {};
  for (const item of items) {
    const bucket = String(item[key]);
    (groups[bucket] ??= []).push(item);
  }
  return groups;
}
TS

cat > src/invoices/types.ts <<'TS'
export interface Customer {
  id: string;
  name: string;
  email: string;
}

export interface Invoice {
  number: string;
  customer: Customer;
  status: "draft" | "sent" | "paid" | "overdue";
  amountDueCents: number;
}
TS

cat > src/invoices/statusCounts.ts <<'TS'
import { groupBy } from "../lib/groupBy.js";
import type { Invoice } from "./types.js";

export function statusCounts(invoices: Invoice[]): Record<string, number> {
  const groups = groupBy(invoices, "status");
  return Object.fromEntries(Object.entries(groups).map(([status, list]) => [status, list.length]));
}
TS

git add -A
git commit -q -m "Invoice status counts"

# Uncommitted: one reminder email per customer listing their overdue invoices.
cat > src/reminders/overdueReminders.ts <<'TS'
import { groupBy } from "../lib/groupBy.js";
import type { Invoice } from "../invoices/types.js";

export interface ReminderEmail {
  to: string;
  subject: string;
  lines: string[];
  totalDueCents: number;
}

export function buildOverdueReminders(invoices: Invoice[]): ReminderEmail[] {
  const overdue = invoices.filter((invoice) => invoice.status === "overdue");
  const byCustomer = groupBy(overdue, "customer");

  return Object.values(byCustomer).map((customerInvoices) => {
    const customer = customerInvoices[0].customer;
    return {
      to: customer.email,
      subject: `${customer.name}: ${customerInvoices.length} overdue invoice(s)`,
      lines: customerInvoices.map((i) => `${i.number}: $${(i.amountDueCents / 100).toFixed(2)}`),
      totalDueCents: customerInvoices.reduce((sum, i) => sum + i.amountDueCents, 0),
    };
  });
}
TS
