#!/bin/bash
# A small Node service that lints with typescript-eslint's type-aware rules,
# and an uncommitted bump of typescript from 5.9 to 7.0 with nothing else.
set -euo pipefail
git init -q -b main
git config user.name "Ines Carvalho"
git config user.email "ines.carvalho@example.com"
mkdir -p src .github/workflows

cat > package.json <<'JSON'
{
  "name": "rota-service",
  "version": "1.8.2",
  "private": true,
  "type": "module",
  "engines": { "node": ">=22" },
  "scripts": {
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "lint": "eslint ."
  },
  "devDependencies": {
    "@types/node": "^22.10.0",
    "eslint": "^9.39.0",
    "typescript": "~5.9.3",
    "typescript-eslint": "^8.72.1"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2023",
    "module": "nodenext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "outDir": "dist",
    "rootDir": "src",
    "types": ["node"]
  },
  "include": ["src"]
}
JSON

cat > eslint.config.js <<'JS'
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["dist/", "eslint.config.js"] },
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname },
    },
    rules: {
      "@typescript-eslint/no-floating-promises": "error",
      "@typescript-eslint/switch-exhaustiveness-check": "error",
    },
  },
);
JS

cat > .github/workflows/ci.yml <<'YML'
name: ci
on: [push, pull_request]
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm install --no-audit --no-fund
      - run: npm run lint
      - run: npm run typecheck
      - run: npm run build
YML

cat > src/shifts.ts <<'TS'
export type ShiftKind = "morning" | "afternoon" | "night";

export interface Shift {
  id: string;
  kind: ShiftKind;
  date: string;
  volunteerIds: string[];
}

export function startHour(kind: ShiftKind): number {
  switch (kind) {
    case "morning":
      return 7;
    case "afternoon":
      return 13;
    case "night":
      return 21;
  }
}

export function isFull(shift: Shift, capacity: number): boolean {
  return shift.volunteerIds.length >= capacity;
}
TS

cat > src/rota.ts <<'TS'
import { isFull, startHour, type Shift } from "./shifts.js";

export interface RotaLine {
  date: string;
  starts: string;
  open: boolean;
}

export function rotaLines(shifts: readonly Shift[], capacity: number): RotaLine[] {
  return shifts.map((s) => ({
    date: s.date,
    starts: `${String(startHour(s.kind)).padStart(2, "0")}:00`,
    open: !isFull(s, capacity),
  }));
}
TS

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { rotaLines } from "./rota.js";
import type { Shift } from "./shifts.js";

const shifts: Shift[] = [
  { id: "s1", kind: "morning", date: "2026-11-09", volunteerIds: ["v1", "v2"] },
  { id: "s2", kind: "night", date: "2026-11-09", volunteerIds: [] },
];

const server = createServer((_req, res) => {
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify(rotaLines(shifts, 3)));
});

server.listen(Number(process.env.PORT ?? 8080));
TS

cat > README.md <<'MD'
# rota-service

Serves the volunteer rota as JSON. `npm run lint`, `npm run typecheck` and
`npm run build` all run in CI.
MD

git add -A
git commit -q -m "Rota service with type-aware lint in CI"

# The uncommitted change: TypeScript 5.9 to 7.0, nothing else.
sed -i.bak 's/"typescript": "~5.9.3"/"typescript": "^7.0.2"/' package.json && rm package.json.bak
cat >> README.md <<'MD'

TypeScript 7 (the native compiler) since 1.9.0: the type check is several
times faster.
MD
