#!/bin/bash
# A small Next.js App Router app for project workspaces, committed, plus an
# uncommitted change that adds deleting a project from its page through a
# Server Action.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app/projects/'[id]' lib prisma
cat > package.json <<'JSON'
{
  "name": "workspaces-web",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "typecheck": "tsc --noEmit",
    "lint": "eslint ."
  },
  "dependencies": {
    "@prisma/client": "^6.18.0",
    "next": "^16.4.0",
    "react": "^19.3.0",
    "react-dom": "^19.3.0",
    "zod": "^4.1.0"
  },
  "devDependencies": {
    "@types/node": "^22.0.0",
    "@types/react": "^19.2.0",
    "eslint": "^9.38.0",
    "eslint-config-next": "^16.4.0",
    "prisma": "^6.18.0",
    "typescript": "^5.9.0"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["dom", "dom.iterable", "esnext"],
    "strict": true,
    "noEmit": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "paths": { "@/*": ["./*"] },
    "plugins": [{ "name": "next" }]
  },
  "include": ["**/*.ts", "**/*.tsx"]
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

model User {
  id       String    @id @default(cuid())
  email    String    @unique
  name     String
  projects Project[]
}

model Project {
  id        String   @id @default(cuid())
  name      String
  ownerId   String
  owner     User     @relation(fields: [ownerId], references: [id])
  createdAt DateTime @default(now())
}
PRISMA
cat > lib/db.ts <<'TS'
import "server-only";
import { PrismaClient } from "@prisma/client";

const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient };

export const db = globalForPrisma.prisma ?? new PrismaClient();

if (process.env.NODE_ENV !== "production") globalForPrisma.prisma = db;
TS
cat > lib/auth.ts <<'TS'
import "server-only";
import { cookies } from "next/headers";
import { db } from "./db";

export type Session = { user: { id: string; email: string } };

// Reads the signed session cookie set at sign-in and returns the signed-in
// user, or null for anonymous requests.
export async function getSession(): Promise<Session | null> {
  const token = (await cookies()).get("session")?.value;
  if (!token) return null;
  const row = await db.$queryRaw<{ user_id: string; email: string }[]>`
    select s.user_id, u.email from sessions s join "User" u on u.id = s.user_id
    where s.token = ${token} and s.expires_at > now()`;
  return row[0] ? { user: { id: row[0].user_id, email: row[0].email } } : null;
}
TS
cat > app/layout.tsx <<'TSX'
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
TSX
cat > app/projects/actions.ts <<'TS'
"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";
import { db } from "@/lib/db";
import { getSession } from "@/lib/auth";

const ProjectName = z.string().trim().min(1).max(80);

export async function renameProject(projectId: string, name: string) {
  const session = await getSession();
  if (!session) throw new Error("Not signed in");
  const { count } = await db.project.updateMany({
    where: { id: projectId, ownerId: session.user.id },
    data: { name: ProjectName.parse(name) },
  });
  if (count === 0) throw new Error("Project not found");
  revalidatePath(`/projects/${projectId}`);
}
TS
cat > 'app/projects/[id]/page.tsx' <<'TSX'
import { notFound, redirect } from "next/navigation";
import { db } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { RenameForm } from "./rename-form";

export default async function ProjectPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await getSession();
  if (!session) redirect("/login");
  const { id } = await params;
  const project = await db.project.findFirst({
    where: { id, ownerId: session.user.id },
    select: { id: true, name: true, createdAt: true },
  });
  if (!project) notFound();
  return (
    <main>
      <h1>{project.name}</h1>
      <p>Created {project.createdAt.toISOString().slice(0, 10)}</p>
      <RenameForm projectId={project.id} name={project.name} />
    </main>
  );
}
TSX
cat > 'app/projects/[id]/rename-form.tsx' <<'TSX'
"use client";

import { useState, useTransition } from "react";
import { renameProject } from "../actions";

export function RenameForm({ projectId, name }: { projectId: string; name: string }) {
  const [value, setValue] = useState(name);
  const [pending, startTransition] = useTransition();
  return (
    <form
      action={() => startTransition(() => renameProject(projectId, value))}
    >
      <input value={value} onChange={(e) => setValue(e.target.value)} aria-label="Project name" />
      <button disabled={pending}>Rename</button>
    </form>
  );
}
TSX
git add -A
git commit -q -m "Project page with rename"

# The uncommitted change: deleting a project, checked like renameProject.
cat >> app/projects/actions.ts <<'TS'

const ProjectId = z.string().min(1).max(64);

export async function deleteProject(projectId: string) {
  const session = await getSession();
  if (!session) throw new Error("Not signed in");
  // Scoped to the owner, so another user's id deletes nothing.
  const { count } = await db.project.deleteMany({
    where: { id: ProjectId.parse(projectId), ownerId: session.user.id },
  });
  if (count === 0) throw new Error("Project not found");
  revalidatePath("/projects");
}
TS
cat > 'app/projects/[id]/delete-button.tsx' <<'TSX'
"use client";

import { useRouter } from "next/navigation";
import { useTransition } from "react";
import { deleteProject } from "../actions";

export function DeleteButton({ projectId }: { projectId: string }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  return (
    <button
      disabled={pending}
      onClick={() => {
        if (!confirm("Delete this project? This can't be undone.")) return;
        startTransition(async () => {
          await deleteProject(projectId);
          router.push("/projects");
        });
      }}
    >
      Delete project
    </button>
  );
}
TSX
cat > 'app/projects/[id]/page.tsx' <<'TSX'
import { notFound, redirect } from "next/navigation";
import { db } from "@/lib/db";
import { getSession } from "@/lib/auth";
import { RenameForm } from "./rename-form";
import { DeleteButton } from "./delete-button";

export default async function ProjectPage({ params }: { params: Promise<{ id: string }> }) {
  const session = await getSession();
  if (!session) redirect("/login");
  const { id } = await params;
  const project = await db.project.findFirst({
    where: { id, ownerId: session.user.id },
    select: { id: true, name: true, createdAt: true },
  });
  if (!project) notFound();
  return (
    <main>
      <h1>{project.name}</h1>
      <p>Created {project.createdAt.toISOString().slice(0, 10)}</p>
      <RenameForm projectId={project.id} name={project.name} />
      {/* Only the owner reaches this page, so only the owner sees Delete. */}
      <DeleteButton projectId={project.id} />
    </main>
  );
}
TSX
