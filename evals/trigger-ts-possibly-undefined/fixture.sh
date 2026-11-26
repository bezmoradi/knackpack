#!/bin/bash
# A small TypeScript pricing module that fails tsc under strict mode with
# "'perSeat' is possibly 'undefined'". The user asks for a proper fix, which is
# TypeScript engineering, not a TypeScript review.
set -euo pipefail
git init -q -b main
git config user.name "Priya Natarajan"
git config user.email "priya@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "pricing",
  "version": "0.2.0",
  "private": true,
  "type": "module",
  "scripts": { "typecheck": "tsc --noEmit" },
  "devDependencies": { "typescript": "5.9.3" }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noEmit": true
  },
  "include": ["src"]
}
JSON
cat > src/prices.ts <<'TS'
export type Plan = "starter" | "team" | "enterprise";

const monthlyCents: Record<string, number> = {
  starter: 900,
  team: 4900,
  enterprise: 19900,
};

export function priceFor(plan: string, seats: number): number {
  const perSeat = monthlyCents[plan];
  return perSeat * seats;
}
TS
git add -A
git commit -qm "Plan pricing"
