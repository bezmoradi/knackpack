#!/bin/bash
# A fleet maintenance dashboard (Vite, type-checked by tsc --noEmit) whose
# tsconfig uses baseUrl and moduleResolution "node", plus an uncommitted bump
# of typescript to 7.
set -euo pipefail
git init -q -b main
git config user.name "Dmitri Volkov"
git config user.email "dmitri.volkov@example.com"
mkdir -p src/vehicles src/services .github/workflows

cat > package.json <<'JSON'
{
  "name": "fleetcare-dashboard",
  "version": "5.2.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit -p . && vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "typescript": "^5.8.3",
    "vite": "^7.1.4"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["es2022", "dom", "dom.iterable"],
    "module": "esnext",
    "moduleResolution": "node",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "strict": true,
    "isolatedModules": true,
    "noEmit": true
  },
  "include": ["src"]
}
JSON

cat > vite.config.ts <<'TS'
import { fileURLToPath } from "node:url";
import { defineConfig } from "vite";

export default defineConfig({
  resolve: {
    alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) },
  },
});
TS

cat > .github/workflows/ci.yml <<'YAML'
name: ci
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
      - run: npm ci
      - run: npm run build
YAML

cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Fleet service schedule</title>
  <script type="module" src="/src/main.ts"></script>
</head>
<body>
  <h1>Due for service</h1>
  <ul id="due"></ul>
</body>
</html>
HTML

cat > src/vehicles/types.ts <<'TS'
export interface Vehicle {
  id: string;
  registration: string;
  odometerKm: number;
  lastServiceKm: number;
}
TS

cat > src/services/schedule.ts <<'TS'
import type { Vehicle } from "@/vehicles/types";

export const SERVICE_INTERVAL_KM = 15000;

export function kmUntilService(vehicle: Vehicle): number {
  return vehicle.lastServiceKm + SERVICE_INTERVAL_KM - vehicle.odometerKm;
}

export function dueForService(fleet: Vehicle[]): Vehicle[] {
  return fleet.filter((v) => kmUntilService(v) <= 500);
}
TS

cat > src/main.ts <<'TS'
import { dueForService, kmUntilService } from "@/services/schedule";
import type { Vehicle } from "@/vehicles/types";

async function render(): Promise<void> {
  const res = await fetch("/api/vehicles");
  const fleet: Vehicle[] = await res.json();
  const list = document.querySelector<HTMLUListElement>("#due");
  if (!list) return;
  list.replaceChildren(
    ...dueForService(fleet).map((v) => {
      const item = document.createElement("li");
      item.textContent = `${v.registration}: ${kmUntilService(v)} km left`;
      return item;
    }),
  );
}

void render();
TS

cat > README.md <<'MD'
# fleetcare-dashboard

Service schedules for the delivery fleet.

- `npm run dev` starts the Vite dev server.
- `npm run build` type-checks with tsc, then bundles with Vite; CI runs it on
  every push.
MD

git add -A
git commit -q -m "Dashboard of vehicles due for service"

# Uncommitted: move to TypeScript 7 for faster type checks.
cat > package.json <<'JSON'
{
  "name": "fleetcare-dashboard",
  "version": "5.2.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit -p . && vite build",
    "preview": "vite preview"
  },
  "devDependencies": {
    "typescript": "^7.0.2",
    "vite": "^7.1.4"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["es2022", "dom", "dom.iterable"],
    "module": "esnext",
    "moduleResolution": "node",
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    },
    "strict": true,
    "isolatedModules": true,
    "noEmit": true,
    "ignoreDeprecations": "6.0"
  },
  "include": ["src"]
}
JSON
