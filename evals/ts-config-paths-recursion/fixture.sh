#!/bin/bash
# A storefront's typed configuration, plus an uncommitted dotted-path accessor
# whose recursive Paths<T> type walks into the self-referencing MenuItem.
set -euo pipefail
git init -q -b main
git config user.name "Chiara Bassi"
git config user.email "chiara.bassi@example.com"
mkdir -p src/config config

cat > package.json <<'JSON'
{
  "name": "storefront-server",
  "version": "5.2.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/server.js"
  },
  "devDependencies": {
    "@types/node": "^22.15.0",
    "typescript": "^5.9.3"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "resolveJsonModule": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/config/schema.ts <<'TS'
export interface MenuItem {
  label: string;
  href: string;
  children: MenuItem[];
}

export interface AppConfig {
  server: { host: string; port: number };
  database: { url: string; pool: { min: number; max: number } };
  checkout: { currency: string; freeShippingOverCents: number };
  navigation: { header: MenuItem[]; footer: MenuItem[] };
}
TS

cat > src/config/load.ts <<'TS'
import { readFileSync } from "node:fs";
import type { AppConfig } from "./schema.js";

export function loadConfig(file = process.env.STOREFRONT_CONFIG ?? "config/default.json"): AppConfig {
  return JSON.parse(readFileSync(file, "utf8")) as AppConfig;
}
TS

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { loadConfig } from "./config/load.js";

const config = loadConfig();

createServer((_req, res) => {
  res.setHeader("content-type", "application/json");
  res.end(JSON.stringify({ menu: config.navigation.header, currency: config.checkout.currency }));
}).listen(config.server.port, config.server.host);
TS

cat > config/default.json <<'JSON'
{
  "server": { "host": "0.0.0.0", "port": 3000 },
  "database": { "url": "postgres://storefront@localhost/storefront", "pool": { "min": 2, "max": 10 } },
  "checkout": { "currency": "EUR", "freeShippingOverCents": 5000 },
  "navigation": {
    "header": [
      { "label": "Shop", "href": "/shop", "children": [
        { "label": "New in", "href": "/shop/new", "children": [] },
        { "label": "Sale", "href": "/shop/sale", "children": [] }
      ] },
      { "label": "Stores", "href": "/stores", "children": [] }
    ],
    "footer": [
      { "label": "Returns", "href": "/help/returns", "children": [] }
    ]
  }
}
JSON

git add -A
git commit -q -m "Storefront server with typed config"

# Uncommitted: read settings by dotted path, with the path checked against AppConfig.
cat > src/config/get.ts <<'TS'
import type { AppConfig } from "./schema.js";

// Every dotted path into T, e.g. "server.port" or "navigation.header.0.label".
export type Paths<T> = T extends readonly (infer Item)[]
  ? `${number}` | `${number}.${Paths<Item>}`
  : T extends object
    ? (keyof T & string) extends infer Key
      ? Key extends keyof T & string
        ? Key | `${Key}.${Paths<T[Key]>}`
        : never
      : never
    : never;

// The type found at a dotted path.
export type PathValue<T, P extends string> = P extends `${infer Head}.${infer Rest}`
  ? T extends readonly (infer Item)[]
    ? PathValue<Item, Rest>
    : Head extends keyof T
      ? PathValue<T[Head], Rest>
      : never
  : T extends readonly (infer Item)[]
    ? Item
    : P extends keyof T
      ? T[P]
      : never;

export function getConfigValue<P extends Paths<AppConfig>>(config: AppConfig, path: P): PathValue<AppConfig, P> {
  let value: unknown = config;
  for (const part of path.split(".")) {
    value = (value as Record<string, unknown>)[part];
  }
  return value as PathValue<AppConfig, P>;
}
TS

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { getConfigValue } from "./config/get.js";
import { loadConfig } from "./config/load.js";

const config = loadConfig();

createServer((_req, res) => {
  res.setHeader("content-type", "application/json");
  res.end(
    JSON.stringify({
      menu: getConfigValue(config, "navigation.header"),
      currency: getConfigValue(config, "checkout.currency"),
    }),
  );
}).listen(getConfigValue(config, "server.port"), getConfigValue(config, "server.host"));
TS
