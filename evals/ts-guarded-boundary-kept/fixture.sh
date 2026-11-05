#!/bin/bash
# A restaurant kitchen display, plus an uncommitted hand-written runtime guard
# that checks every field of the orders feed before the display uses it.
set -euo pipefail
git init -q -b main
git config user.name "Lucía Fernández"
git config user.email "lucia.fernandez@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "kitchen-display",
  "version": "2.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build"
  },
  "devDependencies": {
    "typescript": "^5.9.3",
    "vite": "^7.1.5"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "noEmit": true,
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
JSON
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > src/types.ts <<'TS'
export type OrderStatus = "received" | "cooking" | "ready";

export interface OrderLine {
  menuItemId: string;
  name: string;
  quantity: number;
  modifiers: string[];
}

export interface Order {
  id: string;
  table: number | null; // null for takeaway
  status: OrderStatus;
  placedAt: string; // ISO 8601
  lines: OrderLine[];
  notes?: string;
}
TS
cat > src/orders-api.ts <<'TS'
import type { Order } from "./types";

export async function fetchOpenOrders(signal?: AbortSignal): Promise<Order[]> {
  const res = await fetch("/api/kitchen/orders?status=open", { signal });
  if (!res.ok) throw new Error(`Loading orders failed: ${res.status}`);
  return (await res.json()) as Order[];
}
TS
cat > src/render.ts <<'TS'
import type { Order } from "./types";

export function renderOrderCard(order: Order): HTMLElement {
  const card = document.createElement("article");
  card.className = `order order--${order.status}`;

  const heading = document.createElement("h2");
  heading.textContent = order.table === null ? `Takeaway #${order.id}` : `Table ${order.table}`;
  card.append(heading);

  const list = document.createElement("ul");
  for (const line of order.lines) {
    const item = document.createElement("li");
    const extras = line.modifiers.length > 0 ? ` (${line.modifiers.join(", ")})` : "";
    item.textContent = `${line.quantity} x ${line.name}${extras}`;
    list.append(item);
  }
  card.append(list);

  if (order.notes) {
    const notes = document.createElement("p");
    notes.className = "order__notes";
    notes.textContent = order.notes;
    card.append(notes);
  }
  return card;
}
TS
cat > src/main.ts <<'TS'
import { fetchOpenOrders } from "./orders-api";
import { renderOrderCard } from "./render";

const board = document.querySelector<HTMLElement>("#board")!;

async function refresh(): Promise<void> {
  const orders = await fetchOpenOrders();
  board.replaceChildren(...orders.map(renderOrderCard));
}

setInterval(() => void refresh(), 5_000);
void refresh();
TS
git add -A
git commit -q -m "Kitchen display board polling open orders"

# Uncommitted: validate the orders feed instead of trusting it.
cat > src/order-guard.ts <<'TS'
import type { Order, OrderLine, OrderStatus } from "./types";

// Keyed by every status, so adding one to OrderStatus fails to compile until it's listed here.
const STATUSES = { received: true, cooking: true, ready: true } satisfies Record<OrderStatus, true>;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isStatus(value: unknown): value is OrderStatus {
  return typeof value === "string" && Object.hasOwn(STATUSES, value);
}

function isOrderLine(value: unknown): value is OrderLine {
  return (
    isRecord(value) &&
    typeof value.menuItemId === "string" &&
    typeof value.name === "string" &&
    typeof value.quantity === "number" &&
    Number.isInteger(value.quantity) &&
    value.quantity > 0 &&
    Array.isArray(value.modifiers) &&
    value.modifiers.every((modifier) => typeof modifier === "string")
  );
}

export function isOrder(value: unknown): value is Order {
  return (
    isRecord(value) &&
    typeof value.id === "string" &&
    (value.table === null || (typeof value.table === "number" && Number.isInteger(value.table))) &&
    isStatus(value.status) &&
    typeof value.placedAt === "string" &&
    !Number.isNaN(Date.parse(value.placedAt)) &&
    Array.isArray(value.lines) &&
    value.lines.every(isOrderLine) &&
    (value.notes === undefined || typeof value.notes === "string")
  );
}
TS
cat > src/orders-api.ts <<'TS'
import { isOrder } from "./order-guard";
import type { Order } from "./types";

export class InvalidOrderFeedError extends Error {
  override name = "InvalidOrderFeedError";
}

export async function fetchOpenOrders(signal?: AbortSignal): Promise<Order[]> {
  const res = await fetch("/api/kitchen/orders?status=open", { signal });
  if (!res.ok) throw new Error(`Loading orders failed: ${res.status}`);
  const body: unknown = await res.json();
  if (!Array.isArray(body)) {
    throw new InvalidOrderFeedError("The orders feed did not return a list");
  }
  // Reject the whole response rather than skip the entry: dropping one ticket
  // would make an order vanish from the board without anyone noticing.
  const orders: Order[] = [];
  for (const [index, entry] of body.entries()) {
    if (!isOrder(entry)) {
      throw new InvalidOrderFeedError(`Order ${index + 1} in the feed has an unexpected shape`);
    }
    orders.push(entry);
  }
  return orders;
}
TS
cat > src/main.ts <<'TS'
import { fetchOpenOrders } from "./orders-api";
import { renderOrderCard } from "./render";

const board = document.querySelector<HTMLElement>("#board")!;
const banner = document.querySelector<HTMLElement>("#feed-status")!;

async function refresh(): Promise<void> {
  try {
    const orders = await fetchOpenOrders();
    board.replaceChildren(...orders.map(renderOrderCard));
    banner.hidden = true;
  } catch (error) {
    // Keep the last good board on screen so cooks don't lose the tickets they're working on.
    banner.textContent = `Orders not updated: ${error instanceof Error ? error.message : "unknown error"}`;
    banner.hidden = false;
  }
}

async function poll(): Promise<void> {
  await refresh();
  setTimeout(() => void poll(), 5_000);
}

void poll();
TS
