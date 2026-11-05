#!/bin/bash
# A Node ESM stock service compiled by tsc and run with node, plus an uncommitted
# switch to moduleResolution bundler that drops the .js extensions from imports.
set -euo pipefail
git init -q -b main
git config user.name "Tomasz Wierzbicki"
git config user.email "tomasz.w@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "stock-levels-service",
  "version": "2.3.1",
  "private": true,
  "type": "module",
  "engines": {
    "node": ">=22"
  },
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/server.js"
  },
  "devDependencies": {
    "@types/node": "^24.3.0",
    "typescript": "^5.9.3"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "rootDir": "src",
    "outDir": "dist",
    "sourceMap": true,
    "types": ["node"]
  },
  "include": ["src"]
}
JSON
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > Dockerfile <<'DOCKER'
FROM node:22-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

FROM node:22-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist
USER node
CMD ["node", "dist/server.js"]
DOCKER
cat > src/config.ts <<'TS'
export interface Config {
  port: number;
  warehouseCode: string;
}

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const port = Number(env.PORT ?? "3000");
  if (!Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error(`PORT must be a port number, got ${env.PORT}`);
  }
  return { port, warehouseCode: env.WAREHOUSE_CODE ?? "WH-01" };
}
TS
cat > src/stock.ts <<'TS'
export interface StockLevel {
  sku: string;
  onHand: number;
  reserved: number;
}

const levels = new Map<string, StockLevel>([
  ["PALLET-JACK", { sku: "PALLET-JACK", onHand: 4, reserved: 1 }],
  ["SHRINK-WRAP", { sku: "SHRINK-WRAP", onHand: 120, reserved: 30 }],
]);

export function findStock(sku: string): StockLevel | undefined {
  return levels.get(sku);
}

export function available(level: StockLevel): number {
  return Math.max(0, level.onHand - level.reserved);
}
TS
cat > src/routes.ts <<'TS'
import type { IncomingMessage, ServerResponse } from "node:http";
import { available, findStock } from "./stock.js";

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

export function handle(req: IncomingMessage, res: ServerResponse, warehouseCode: string): void {
  const url = new URL(req.url ?? "/", "http://localhost");
  const match = /^\/stock\/([A-Z0-9-]+)$/.exec(url.pathname);
  if (req.method === "GET" && match) {
    const level = findStock(match[1]);
    if (!level) return sendJson(res, 404, { error: "unknown sku" });
    return sendJson(res, 200, { warehouseCode, sku: level.sku, available: available(level) });
  }
  sendJson(res, 404, { error: "not found" });
}
TS
cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { loadConfig } from "./config.js";
import { handle } from "./routes.js";

const config = loadConfig();
const server = createServer((req, res) => handle(req, res, config.warehouseCode));

server.listen(config.port, () => {
  console.log(`stock-levels-service listening on ${config.port} (${config.warehouseCode})`);
});
TS
git add -A
git commit -q -m "Stock levels service with per-SKU availability endpoint"

# Uncommitted: a health endpoint, and imports without extensions.
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2023",
    "module": "esnext",
    "moduleResolution": "bundler",
    "strict": true,
    "rootDir": "src",
    "outDir": "dist",
    "sourceMap": true,
    "types": ["node"]
  },
  "include": ["src"]
}
JSON
cat > src/health.ts <<'TS'
const startedAt = Date.now();

export function healthReport(warehouseCode: string): { status: "ok"; warehouseCode: string; uptimeSeconds: number } {
  return { status: "ok", warehouseCode, uptimeSeconds: Math.round((Date.now() - startedAt) / 1000) };
}
TS
cat > src/routes.ts <<'TS'
import type { IncomingMessage, ServerResponse } from "node:http";
import { healthReport } from "./health";
import { available, findStock } from "./stock";

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
}

export function handle(req: IncomingMessage, res: ServerResponse, warehouseCode: string): void {
  const url = new URL(req.url ?? "/", "http://localhost");
  if (req.method === "GET" && url.pathname === "/healthz") {
    return sendJson(res, 200, healthReport(warehouseCode));
  }
  const match = /^\/stock\/([A-Z0-9-]+)$/.exec(url.pathname);
  if (req.method === "GET" && match) {
    const level = findStock(match[1]);
    if (!level) return sendJson(res, 404, { error: "unknown sku" });
    return sendJson(res, 200, { warehouseCode, sku: level.sku, available: available(level) });
  }
  sendJson(res, 404, { error: "not found" });
}
TS
cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { loadConfig } from "./config";
import { handle } from "./routes";

const config = loadConfig();
const server = createServer((req, res) => handle(req, res, config.warehouseCode));

server.listen(config.port, () => {
  console.log(`stock-levels-service listening on ${config.port} (${config.warehouseCode})`);
});
TS
