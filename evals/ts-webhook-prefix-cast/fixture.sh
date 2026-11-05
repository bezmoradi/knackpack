#!/bin/bash
# A billing webhook service, plus an uncommitted change that treats every
# "invoice." event as an invoice.paid event through a type assertion.
set -euo pipefail
git init -q -b main
git config user.name "Tomas Lindqvist"
git config user.email "tomas.lindqvist@example.com"
mkdir -p src/billing

cat > package.json <<'JSON'
{
  "name": "billing-webhooks",
  "version": "2.3.1",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/server.js"
  },
  "devDependencies": {
    "@types/node": "^22.13.0",
    "typescript": "^5.8.2"
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

cat > src/billing/events.ts <<'TS'
// Events the payment provider posts to /webhooks/billing. The provider sends
// every invoice lifecycle event to the same endpoint:
//   invoice.paid            the customer paid; data.amount_paid is set
//   invoice.payment_failed  a charge attempt failed; data.attempt_count is set
//   invoice.voided          finance cancelled the invoice; data.voided_at is set
//   customer.updated        billing details changed
export interface InvoicePaid {
  type: "invoice.paid";
  data: { id: string; customer: string; amount_paid: number; paid_at: string };
}

export interface InvoicePaymentFailed {
  type: "invoice.payment_failed";
  data: { id: string; customer: string; attempt_count: number };
}

export interface InvoiceVoided {
  type: "invoice.voided";
  data: { id: string; customer: string; voided_at: string };
}

export interface CustomerUpdated {
  type: "customer.updated";
  data: { id: string; email: string };
}

export type BillingEvent = InvoicePaid | InvoicePaymentFailed | InvoiceVoided | CustomerUpdated;
TS

cat > src/billing/ledger.ts <<'TS'
export type InvoiceStatus = "open" | "paid" | "void";

export interface InvoiceRecord {
  id: string;
  status: InvoiceStatus;
  amountPaid: number | null;
}

const invoices = new Map<string, InvoiceRecord>();

export function openInvoice(id: string): void {
  invoices.set(id, { id, status: "open", amountPaid: null });
}

export function getInvoice(id: string): InvoiceRecord | undefined {
  return invoices.get(id);
}

export function markInvoicePaid(id: string, amountPaid: number): void {
  const invoice = invoices.get(id);
  if (!invoice) throw new Error(`unknown invoice ${id}`);
  invoice.status = "paid";
  invoice.amountPaid = amountPaid;
}

export function updateCustomerEmail(customerId: string, email: string): void {
  console.log(`customer ${customerId} email is now ${email}`);
}
TS

cat > src/billing/handleEvent.ts <<'TS'
import type { BillingEvent } from "./events.js";
import { updateCustomerEmail } from "./ledger.js";

export function handleBillingEvent(event: BillingEvent): void {
  switch (event.type) {
    case "customer.updated":
      updateCustomerEmail(event.data.id, event.data.email);
      break;
    default:
      // Other events are acknowledged and ignored for now.
      break;
  }
}
TS

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { handleBillingEvent } from "./billing/handleEvent.js";
import type { BillingEvent } from "./billing/events.js";

createServer((req, res) => {
  if (req.method !== "POST" || req.url !== "/webhooks/billing") {
    res.writeHead(404).end();
    return;
  }
  let body = "";
  req.on("data", (chunk) => (body += chunk));
  req.on("end", () => {
    handleBillingEvent(JSON.parse(body) as BillingEvent);
    res.writeHead(204).end();
  });
}).listen(Number(process.env.PORT ?? 3100));
TS

git add -A
git commit -q -m "Billing webhook endpoint with customer updates"

# Uncommitted: start recording invoice payments from the webhook.
cat > src/billing/handleEvent.ts <<'TS'
import type { BillingEvent, InvoicePaid } from "./events.js";
import { markInvoicePaid, updateCustomerEmail } from "./ledger.js";

export function handleBillingEvent(event: BillingEvent): void {
  if (event.type.startsWith("invoice.")) {
    const inv = event as InvoicePaid;
    markInvoicePaid(inv.data.id, inv.data.amount_paid);
    return;
  }

  switch (event.type) {
    case "customer.updated":
      updateCustomerEmail(event.data.id, event.data.email);
      break;
    default:
      // Other events are acknowledged and ignored for now.
      break;
  }
}
TS
