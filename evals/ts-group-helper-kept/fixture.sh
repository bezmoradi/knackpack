#!/bin/bash
# A support desk's daily digest script, plus an uncommitted generic groupBy
# helper whose type parameters tie the key function to the result's keys.
set -euo pipefail
git init -q -b main
git config user.name "Daniel Achterberg"
git config user.email "daniel.achterberg@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "support-digest",
  "version": "1.2.0",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=18.18"
  },
  "scripts": {
    "build": "tsc -p .",
    "digest": "node dist/main.js"
  },
  "devDependencies": {
    "@types/node": "^18.19.0",
    "typescript": "^5.9.3"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022"],
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
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
export type TicketStatus = "new" | "open" | "pending" | "solved";

export interface Ticket {
  id: number;
  subject: string;
  status: TicketStatus;
  assigneeEmail: string | null;
  openedAt: string; // ISO 8601
}
TS
cat > src/tickets.ts <<'TS'
import type { Ticket } from "./types.js";

// Yesterday's export from the help desk, used until the API client lands.
export const tickets: Ticket[] = [
  { id: 4101, subject: "Refund not received", status: "open", assigneeEmail: "sam@example.com", openedAt: "2026-06-03T08:12:00Z" },
  { id: 4102, subject: "Change delivery address", status: "solved", assigneeEmail: "ana@example.com", openedAt: "2026-06-03T08:40:00Z" },
  { id: 4103, subject: "Login link expired", status: "new", assigneeEmail: null, openedAt: "2026-06-03T09:05:00Z" },
  { id: 4104, subject: "Damaged item", status: "pending", assigneeEmail: "sam@example.com", openedAt: "2026-06-03T10:30:00Z" },
  { id: 4105, subject: "Invoice copy", status: "open", assigneeEmail: "ana@example.com", openedAt: "2026-06-03T11:15:00Z" },
  { id: 4106, subject: "Cancel subscription", status: "open", assigneeEmail: "sam@example.com", openedAt: "2026-06-03T12:02:00Z" },
];
TS
cat > src/main.ts <<'TS'
import { tickets } from "./tickets.js";

const unsolved = tickets.filter((ticket) => ticket.status !== "solved");
console.log(`Support digest: ${unsolved.length} unsolved of ${tickets.length} tickets`);
TS
git add -A
git commit -q -m "Daily support digest with unsolved count"

# Uncommitted: per-status and per-agent sections, using a shared helper.
cat > src/collections.ts <<'TS'
/**
 * Groups items by the key keyOf returns. Only keys that occur are present.
 * Object.groupBy does the same, but needs Node 21 and we still support 18.
 */
export function groupBy<T, K extends PropertyKey>(
  items: readonly T[],
  keyOf: (item: T) => K,
): Partial<Record<K, T[]>> {
  // A null prototype, so keys such as "constructor" or "__proto__" start empty too.
  const groups = Object.create(null) as Partial<Record<K, T[]>>;
  for (const item of items) {
    const key = keyOf(item);
    (groups[key] ??= []).push(item);
  }
  return groups;
}
TS
cat > src/digest.ts <<'TS'
import { groupBy } from "./collections.js";
import type { Ticket, TicketStatus } from "./types.js";

const STATUS_ORDER: readonly TicketStatus[] = ["new", "open", "pending", "solved"];

export function statusSection(tickets: readonly Ticket[]): string[] {
  const byStatus = groupBy(tickets, (ticket) => ticket.status);
  return STATUS_ORDER.map((status) => `  ${status.padEnd(8)} ${byStatus[status]?.length ?? 0}`);
}

export function workloadSection(tickets: readonly Ticket[]): string[] {
  const unsolved = tickets.filter((ticket) => ticket.status !== "solved");
  const byAssignee = groupBy(unsolved, (ticket) => ticket.assigneeEmail ?? "unassigned");
  return Object.entries(byAssignee)
    .map(([assignee, assigned = []]) => ({ assignee, count: assigned.length }))
    .sort((a, b) => b.count - a.count || a.assignee.localeCompare(b.assignee))
    .map(({ assignee, count }) => `  ${assignee.padEnd(18)} ${count}`);
}
TS
cat > src/main.ts <<'TS'
import { statusSection, workloadSection } from "./digest.js";
import { tickets } from "./tickets.js";

const unsolved = tickets.filter((ticket) => ticket.status !== "solved");
console.log(`Support digest: ${unsolved.length} unsolved of ${tickets.length} tickets`);
console.log("By status:");
console.log(statusSection(tickets).join("\n"));
console.log("Open work by agent:");
console.log(workloadSection(tickets).join("\n"));
TS
