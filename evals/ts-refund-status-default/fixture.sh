#!/bin/bash
# An online bookshop's order pages, plus an uncommitted refund flow that adds a
# "refunded" status which an existing switch's default labels as "Paid".
set -euo pipefail
git init -q -b main
git config user.name "Kwame Mensah"
git config user.email "kwame.mensah@example.com"
mkdir -p src/orders src/support

cat > package.json <<'JSON'
{
  "name": "pagewise-orders",
  "version": "4.6.2",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "lint:types": "tsc -p . --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.7.3"
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
    "noFallthroughCasesInSwitch": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/orders/types.ts <<'TS'
export type OrderStatus = "pending" | "paid" | "shipped" | "cancelled";

export interface Order {
  id: string;
  customerEmail: string;
  status: OrderStatus;
  totalCents: number;
}
TS

cat > src/orders/statusLabel.ts <<'TS'
import type { OrderStatus } from "./types.js";

// Shown to customers on the order page and in emails, and to support staff.
export function statusLabel(status: OrderStatus): string {
  switch (status) {
    case "pending":
      return "Awaiting payment";
    case "shipped":
      return "Shipped";
    case "cancelled":
      return "Cancelled";
    default:
      return "Paid";
  }
}
TS

cat > src/orders/orderSummary.ts <<'TS'
import { statusLabel } from "./statusLabel.js";
import type { Order } from "./types.js";

export function orderSummary(order: Order): string {
  const total = (order.totalCents / 100).toFixed(2);
  return `Order ${order.id}: ${statusLabel(order.status)} (total $${total})`;
}
TS

cat > src/support/ticketHeader.ts <<'TS'
import { statusLabel } from "../orders/statusLabel.js";
import type { Order } from "../orders/types.js";

export function ticketHeader(order: Order): string {
  return `[${statusLabel(order.status)}] ${order.id} <${order.customerEmail}>`;
}
TS

git add -A
git commit -q -m "Order summary and support ticket header"

# Uncommitted: support can refund an order.
cat > src/orders/types.ts <<'TS'
export type OrderStatus = "pending" | "paid" | "shipped" | "cancelled" | "refunded";

export interface Order {
  id: string;
  customerEmail: string;
  status: OrderStatus;
  totalCents: number;
}
TS

cat > src/orders/refunds.ts <<'TS'
import { orderSummary } from "./orderSummary.js";
import type { Order } from "./types.js";

export interface RefundResult {
  order: Order;
  customerMessage: string;
}

export function refundOrder(order: Order): RefundResult {
  if (order.status !== "paid" && order.status !== "shipped") {
    throw new Error(`order ${order.id} can't be refunded from ${order.status}`);
  }
  const refunded: Order = { ...order, status: "refunded" };
  return {
    order: refunded,
    customerMessage: `We've refunded your order. ${orderSummary(refunded)}`,
  };
}
TS
