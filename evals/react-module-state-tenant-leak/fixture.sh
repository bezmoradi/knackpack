#!/bin/bash
# A multi-tenant Next.js App Router billing app, committed, plus an
# uncommitted change that stops passing the tenant id to every data function.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app/invoices lib
cat > package.json <<'JSON'
{
  "name": "billing-web",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "start": "next start" },
  "dependencies": {
    "@prisma/client": "^6.18.0",
    "next": "^16.4.0",
    "react": "^19.3.0",
    "react-dom": "^19.3.0"
  },
  "devDependencies": { "@types/react": "^19.2.0", "typescript": "^5.9.0" }
}
JSON
cat > README.md <<'MD'
# Billing web

Every customer company is a tenant. All tenants share one database and one
Node.js server process per region; every query must be scoped to the
signed-in user's tenant.
MD
cat > lib/db.ts <<'TS'
import "server-only";
import { PrismaClient } from "@prisma/client";

export const db = new PrismaClient();
TS
cat > lib/auth.ts <<'TS'
import "server-only";
import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { db } from "./db";

export async function requireSession(): Promise<{ userId: string; tenantId: string }> {
  const token = (await cookies()).get("session")?.value;
  if (!token) redirect("/login");
  const rows = await db.$queryRaw<{ user_id: string; tenant_id: string }[]>`
    select user_id, tenant_id from sessions where token = ${token} and expires_at > now()`;
  if (!rows[0]) redirect("/login");
  return { userId: rows[0].user_id, tenantId: rows[0].tenant_id };
}
TS
cat > lib/invoices.ts <<'TS'
import "server-only";
import { db } from "./db";

export async function listInvoices(tenantId: string) {
  const settings = await db.billingSettings.findUnique({ where: { tenantId } });
  return db.invoice.findMany({
    where: { tenantId, status: settings?.showDrafts ? undefined : { not: "draft" } },
    orderBy: { issuedAt: "desc" },
    select: { id: true, number: true, customerName: true, total: true, status: true },
  });
}
TS
cat > app/invoices/page.tsx <<'TSX'
import { requireSession } from "@/lib/auth";
import { listInvoices } from "@/lib/invoices";

export default async function InvoicesPage() {
  const { tenantId } = await requireSession();
  const invoices = await listInvoices(tenantId);
  return (
    <main>
      <h1>Invoices</h1>
      <ul>
        {invoices.map((i) => (
          <li key={i.id}>
            {i.number} {i.customerName}: {i.total.toString()} ({i.status})
          </li>
        ))}
      </ul>
    </main>
  );
}
TSX
git add -A
git commit -q -m "Invoices page"

# The uncommitted change: set the tenant once per request instead of passing it.
cat > lib/tenant.ts <<'TS'
import "server-only";

// The tenant of the request being rendered. Set once at the top of each page
// so data functions don't need a tenantId parameter.
let currentTenantId: string | null = null;

export function setCurrentTenant(tenantId: string) {
  currentTenantId = tenantId;
}

export function currentTenant(): string {
  if (!currentTenantId) throw new Error("No tenant set for this request");
  return currentTenantId;
}
TS
cat > lib/invoices.ts <<'TS'
import "server-only";
import { db } from "./db";
import { currentTenant } from "./tenant";

export async function listInvoices() {
  const settings = await db.billingSettings.findUnique({ where: { tenantId: currentTenant() } });
  return db.invoice.findMany({
    where: { tenantId: currentTenant(), status: settings?.showDrafts ? undefined : { not: "draft" } },
    orderBy: { issuedAt: "desc" },
    select: { id: true, number: true, customerName: true, total: true, status: true },
  });
}
TS
cat > app/invoices/page.tsx <<'TSX'
import { requireSession } from "@/lib/auth";
import { listInvoices } from "@/lib/invoices";
import { setCurrentTenant } from "@/lib/tenant";

export default async function InvoicesPage() {
  const { tenantId } = await requireSession();
  setCurrentTenant(tenantId);
  const invoices = await listInvoices();
  return (
    <main>
      <h1>Invoices</h1>
      <ul>
        {invoices.map((i) => (
          <li key={i.id}>
            {i.number} {i.customerName}: {i.total.toString()} ({i.status})
          </li>
        ))}
      </ul>
    </main>
  );
}
TSX
