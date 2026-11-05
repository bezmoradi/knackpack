#!/bin/bash
# A wholesale stock importer (ESM) that reads CSV with a CommonJS package,
# plus an uncommitted change that switches to named imports from it.
# The package is committed under node_modules/legacy-csv because the case
# depends on how its index.js builds module.exports, and the run has no network.
set -euo pipefail
git init -q -b main
git config user.name "Owen Gallagher"
git config user.email "owen.gallagher@example.com"
mkdir -p src/importers data node_modules/legacy-csv/lib

cat > package.json <<'JSON'
{
  "name": "stockroom-importer",
  "version": "0.9.3",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "import:suppliers": "node dist/cli.js suppliers data/suppliers.csv",
    "import:stock": "node dist/cli.js stock data/stock-levels.csv"
  },
  "dependencies": {
    "legacy-csv": "2.3.1"
  },
  "devDependencies": {
    "@types/node": "^22.10.5",
    "typescript": "^5.7.3"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "esModuleInterop": true,
    "strict": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > .gitignore <<'TXT'
dist/
TXT

cat > node_modules/legacy-csv/package.json <<'JSON'
{
  "name": "legacy-csv",
  "version": "2.3.1",
  "description": "Small CSV parser",
  "main": "index.js",
  "types": "index.d.ts",
  "license": "MIT"
}
JSON

cat > node_modules/legacy-csv/lib/parse.js <<'JS'
"use strict";

function parse(text, options) {
  var delimiter = (options && options.delimiter) || ",";
  return text
    .split(/\r?\n/)
    .filter(function (line) { return line.length > 0; })
    .map(function (line) { return line.split(delimiter).map(function (cell) { return cell.trim(); }); });
}

function toObjects(rows) {
  var header = rows[0];
  return rows.slice(1).map(function (row) {
    var record = {};
    header.forEach(function (name, i) { record[name] = row[i]; });
    return record;
  });
}

module.exports = { parse: parse, toObjects: toObjects };
JS

cat > node_modules/legacy-csv/index.js <<'JS'
"use strict";

var helpers = require("./lib/parse");

Object.assign(module.exports, helpers, { version: "2.3.1" });
JS

cat > node_modules/legacy-csv/index.d.ts <<'TS'
export interface ParseOptions {
  delimiter?: string;
}
export declare function parse(text: string, options?: ParseOptions): string[][];
export declare function toObjects(rows: string[][]): Record<string, string>[];
export declare const version: string;
TS

cat > data/suppliers.csv <<'CSV'
code,name,email
NRD,Nordic Dry Goods,nordic-orders@example.com
SLT,Saltmarsh Provisions,saltmarsh-trade@example.com
CSV

cat > data/stock-levels.csv <<'CSV'
sku,on_hand,reorder_at
OAT-1KG,140,60
RYE-500G,18,40
CSV

cat > src/importers/suppliers.ts <<'TS'
import csv from "legacy-csv";

export interface Supplier {
  code: string;
  name: string;
  email: string;
}

export function readSuppliers(text: string): Supplier[] {
  return csv.toObjects(csv.parse(text)).map((r) => ({ code: r.code, name: r.name, email: r.email }));
}
TS

cat > src/cli.ts <<'TS'
import { readFileSync } from "node:fs";
import { readSuppliers } from "./importers/suppliers.js";

const [kind, file] = process.argv.slice(2);
const text = readFileSync(file, "utf8");

if (kind === "suppliers") {
  for (const s of readSuppliers(text)) console.log(`${s.code}  ${s.name} <${s.email}>`);
} else {
  console.error(`unknown import: ${kind}`);
  process.exitCode = 1;
}
TS

git add -A
git commit -q -m "Supplier import from CSV"

# Uncommitted: a stock-level import, and named imports instead of csv.*.
cat > src/importers/stockLevels.ts <<'TS'
import { parse, toObjects } from "legacy-csv";

export interface StockLevel {
  sku: string;
  onHand: number;
  reorderAt: number;
}

export function readStockLevels(text: string): StockLevel[] {
  return toObjects(parse(text)).map((r) => ({
    sku: r.sku,
    onHand: Number(r.on_hand),
    reorderAt: Number(r.reorder_at),
  }));
}

export function needsReorder(levels: StockLevel[]): StockLevel[] {
  return levels.filter((l) => l.onHand <= l.reorderAt);
}
TS

cat > src/importers/suppliers.ts <<'TS'
import { parse, toObjects } from "legacy-csv";

export interface Supplier {
  code: string;
  name: string;
  email: string;
}

export function readSuppliers(text: string): Supplier[] {
  return toObjects(parse(text)).map((r) => ({ code: r.code, name: r.name, email: r.email }));
}
TS

cat > src/cli.ts <<'TS'
import { readFileSync } from "node:fs";
import { needsReorder, readStockLevels } from "./importers/stockLevels.js";
import { readSuppliers } from "./importers/suppliers.js";

const [kind, file] = process.argv.slice(2);
const text = readFileSync(file, "utf8");

if (kind === "suppliers") {
  for (const s of readSuppliers(text)) console.log(`${s.code}  ${s.name} <${s.email}>`);
} else if (kind === "stock") {
  for (const l of needsReorder(readStockLevels(text))) {
    console.log(`reorder ${l.sku}: ${l.onHand} on hand, reorder at ${l.reorderAt}`);
  }
} else {
  console.error(`unknown import: ${kind}`);
  process.exitCode = 1;
}
TS
