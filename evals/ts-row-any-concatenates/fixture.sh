#!/bin/bash
# A bank statement importer for an expenses app, plus an uncommitted change that
# makes the CSV parser header-driven and has it return any.
set -euo pipefail
git init -q -b main
git config user.name "Priya Raman"
git config user.email "priya.raman@example.com"
mkdir -p src samples

cat > package.json <<'JSON'
{
  "name": "expense-ledger",
  "version": "1.4.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "import": "node dist/cli.js"
  },
  "devDependencies": {
    "@types/node": "^22.10.0",
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
    "outDir": "dist",
    "rootDir": "src",
    "skipLibCheck": true
  },
  "include": ["src"]
}
JSON

cat > src/types.ts <<'TS'
export interface ParsedRow {
  date: string;
  description: string;
  amount: number;
}

export interface Statement {
  account: string;
  rows: ParsedRow[];
  total: number;
}
TS

cat > src/csv.ts <<'TS'
import type { ParsedRow } from "./types.js";

// Statements arrive as "date,description,amount" with a header line.
export function parseRow(line: string): ParsedRow {
  const [date, description, amount] = line.split(",");
  return { date, description, amount: Number(amount) };
}

export function parseStatement(text: string): ParsedRow[] {
  return text
    .trim()
    .split("\n")
    .slice(1)
    .map(parseRow);
}
TS

cat > src/store.ts <<'TS'
import { writeFile } from "node:fs/promises";
import type { Statement } from "./types.js";

export async function saveStatement(statement: Statement, file: string): Promise<void> {
  await writeFile(file, JSON.stringify(statement, null, 2));
}
TS

cat > src/importStatement.ts <<'TS'
import { readFile } from "node:fs/promises";
import { parseStatement } from "./csv.js";
import { saveStatement } from "./store.js";

export async function importStatement(account: string, csvFile: string, outFile: string) {
  const rows = parseStatement(await readFile(csvFile, "utf8"));
  const total = rows.reduce((sum, row) => sum + row.amount, 0);
  await saveStatement({ account, rows, total }, outFile);
  return total;
}
TS

cat > src/cli.ts <<'TS'
import { importStatement } from "./importStatement.js";

const [account, csvFile, outFile = "statement.json"] = process.argv.slice(2);
if (!account || !csvFile) {
  console.error("usage: npm run import -- <account> <statement.csv> [out.json]");
  process.exit(1);
}
const total = await importStatement(account, csvFile, outFile);
console.log(`Imported statement for ${account}: total ${total}`);
TS

cat > samples/northbank.csv <<'CSV'
date,description,amount
2025-03-02,Office supplies,100.50
2025-03-04,Train ticket,50.00
2025-03-09,Client lunch,42.75
CSV

git add -A
git commit -q -m "Import bank statements from CSV"

# Uncommitted: banks export the columns in different orders, so read them by header name.
cat > src/csv.ts <<'TS'
// Banks export the same columns in different orders, so map each line by the
// header names instead of by position.
export function parseStatement(text: string): any[] {
  const [headerLine, ...lines] = text.trim().split("\n");
  const headers = headerLine.split(",").map((h) => h.trim().toLowerCase());
  return lines.map((line) => {
    const cells = line.split(",");
    const row: Record<string, string> = {};
    headers.forEach((header, i) => {
      row[header] = cells[i]?.trim() ?? "";
    });
    return row;
  });
}
TS

cat > src/importStatement.ts <<'TS'
import { readFile } from "node:fs/promises";
import { parseStatement } from "./csv.js";
import { saveStatement } from "./store.js";

export async function importStatement(account: string, csvFile: string, outFile: string) {
  const rows = parseStatement(await readFile(csvFile, "utf8"));
  let total = 0;
  for (const row of rows) {
    total = total + row.amount;
  }
  await saveStatement({ account, rows, total }, outFile);
  return total;
}
TS

cat > samples/harbor-credit.csv <<'CSV'
amount,date,description
19.99,2025-03-03,Software subscription
240.00,2025-03-11,Conference ticket
CSV
