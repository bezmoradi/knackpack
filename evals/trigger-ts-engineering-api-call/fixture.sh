#!/bin/bash
# A small TypeScript client for a library catalog API. The user asks for one
# more API call, which is ordinary TypeScript work.
set -euo pipefail
git init -q -b main
git config user.name "Priya Natarajan"
git config user.email "priya@example.com"
mkdir -p src docs
cat > package.json <<'JSON'
{
  "name": "catalog-client",
  "version": "0.3.0",
  "private": true,
  "type": "module",
  "scripts": { "typecheck": "tsc --noEmit" },
  "devDependencies": { "typescript": "5.9.3", "@types/node": "^22.10.0" }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "strict": true,
    "noEmit": true,
    "types": ["node"]
  },
  "include": ["src"]
}
JSON
cat > src/catalog.ts <<'TS'
const BASE_URL = process.env.CATALOG_URL ?? "https://catalog.example.org/api";

export interface Book {
  isbn: string;
  title: string;
  authors: string[];
}

function isBook(value: unknown): value is Book {
  if (typeof value !== "object" || value === null) return false;
  const v = value as Record<string, unknown>;
  return (
    typeof v.isbn === "string" &&
    typeof v.title === "string" &&
    Array.isArray(v.authors) &&
    v.authors.every((a) => typeof a === "string")
  );
}

export async function getBook(isbn: string): Promise<Book> {
  const res = await fetch(`${BASE_URL}/books/${encodeURIComponent(isbn)}`);
  if (!res.ok) throw new Error(`catalog returned ${res.status} for ${isbn}`);
  const body: unknown = await res.json();
  if (!isBook(body)) throw new Error(`unexpected book payload for ${isbn}`);
  return body;
}
TS
cat > docs/availability-sample.json <<'JSON'
{
  "isbn": "9780143127741",
  "onShelf": 2,
  "onLoan": 3,
  "nextDue": "2026-11-19",
  "branch": "Central"
}
JSON
git add -A
git commit -q -m "Catalog client with book lookup"
