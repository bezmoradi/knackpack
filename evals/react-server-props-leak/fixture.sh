#!/bin/bash
# A Next.js App Router team settings page, committed, plus an uncommitted
# change that adds a filter box to the member list.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app/team lib prisma
cat > package.json <<'JSON'
{
  "name": "teams-web",
  "private": true,
  "scripts": { "dev": "next dev", "build": "next build", "typecheck": "tsc --noEmit" },
  "dependencies": {
    "@prisma/client": "^6.18.0",
    "next": "^16.4.0",
    "react": "^19.3.0",
    "react-dom": "^19.3.0"
  },
  "devDependencies": {
    "@types/react": "^19.2.0",
    "prisma": "^6.18.0",
    "typescript": "^5.9.0"
  }
}
JSON
cat > prisma/schema.prisma <<'PRISMA'
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model Team {
  id      String @id @default(cuid())
  name    String
  members User[]
}

model User {
  id            String    @id @default(cuid())
  teamId        String
  team          Team      @relation(fields: [teamId], references: [id])
  name          String
  email         String    @unique
  role          String
  passwordHash  String
  totpSecret    String?
  recoveryCodes String[]
  lastLoginIp   String?
  lastLoginAt   DateTime?
}
PRISMA
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

export type Session = { userId: string; teamId: string };

// Every team member, not only admins, can open the team page.
export async function requireSession(): Promise<Session> {
  const token = (await cookies()).get("session")?.value;
  if (!token) redirect("/login");
  const rows = await db.$queryRaw<{ user_id: string; team_id: string }[]>`
    select s.user_id, u."teamId" as team_id from sessions s join "User" u on u.id = s.user_id
    where s.token = ${token} and s.expires_at > now()`;
  if (!rows[0]) redirect("/login");
  return { userId: rows[0].user_id, teamId: rows[0].team_id };
}
TS
cat > app/team/page.tsx <<'TSX'
import { db } from "@/lib/db";
import { requireSession } from "@/lib/auth";

export default async function TeamPage() {
  const session = await requireSession();
  const members = await db.user.findMany({
    where: { teamId: session.teamId },
    select: { id: true, name: true, role: true },
    orderBy: { name: "asc" },
  });
  return (
    <main>
      <h1>Team</h1>
      <ul>
        {members.map((m) => (
          <li key={m.id}>
            {m.name}, {m.role}
          </li>
        ))}
      </ul>
    </main>
  );
}
TSX
git add -A
git commit -q -m "Team page"

# The uncommitted change: a client-side filter over the member list.
cat > app/team/member-list.tsx <<'TSX'
"use client";

import { useState } from "react";
import type { User } from "@prisma/client";

export function MemberList({ members }: { members: User[] }) {
  const [filter, setFilter] = useState("");
  const shown = members.filter((m) => m.name.toLowerCase().includes(filter.toLowerCase()));
  return (
    <>
      <input aria-label="Filter members" value={filter} onChange={(e) => setFilter(e.target.value)} />
      <ul>
        {shown.map((m) => (
          <li key={m.id}>
            {m.name}, {m.role}
          </li>
        ))}
      </ul>
    </>
  );
}
TSX
cat > app/team/page.tsx <<'TSX'
import { db } from "@/lib/db";
import { requireSession } from "@/lib/auth";
import { MemberList } from "./member-list";

export default async function TeamPage() {
  const session = await requireSession();
  // Typed as User so the list can show more columns later without another query.
  const members = await db.user.findMany({
    where: { teamId: session.teamId },
    orderBy: { name: "asc" },
  });
  return (
    <main>
      <h1>Team</h1>
      <MemberList members={members} />
    </main>
  );
}
TSX
