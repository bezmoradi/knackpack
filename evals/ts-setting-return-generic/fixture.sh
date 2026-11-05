#!/bin/bash
# An email delivery worker that reads settings from an env file, plus an
# uncommitted generic getSetting<T>() that only casts the stored string.
set -euo pipefail
git init -q -b main
git config user.name "Yusuf Demir"
git config user.email "yusuf.demir@example.com"
mkdir -p src/config src/delivery config

cat > package.json <<'JSON'
{
  "name": "mail-relay-worker",
  "version": "1.8.4",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/delivery/worker.js"
  },
  "devDependencies": {
    "@types/node": "^22.12.0",
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
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > config/worker.env <<'ENV'
SMTP_HOST=smtp.internal.example.com
SMTP_PORT=587
RETRY_DELAY_MS=1000
MAX_ATTEMPTS=5
SENDER_ADDRESS=notifications@example.com
ENV

cat > src/config/settings.ts <<'TS'
import { readFileSync } from "node:fs";

const SETTINGS_FILE = process.env.WORKER_SETTINGS ?? new URL("../../config/worker.env", import.meta.url);

function load(): Record<string, string> {
  const values: Record<string, string> = {};
  for (const line of readFileSync(SETTINGS_FILE, "utf8").split("\n")) {
    const match = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (match) values[match[1]] = match[2];
  }
  return values;
}

const store = load();

export function getString(key: string): string {
  const value = store[key];
  if (value === undefined) throw new Error(`missing setting ${key}`);
  return value;
}

export function getNumber(key: string): number {
  const value = Number(getString(key));
  if (Number.isNaN(value)) throw new Error(`setting ${key} is not a number`);
  return value;
}
TS

cat > src/delivery/retry.ts <<'TS'
import { getNumber } from "../config/settings.js";

// The provider rate-limits bursts, so every retry waits at least half a second
// beyond the configured delay.
export function retryDelayMs(): number {
  return getNumber("RETRY_DELAY_MS") + 500;
}

export function shouldRetry(attempt: number): boolean {
  return attempt < getNumber("MAX_ATTEMPTS");
}
TS

cat > src/delivery/worker.ts <<'TS'
import { getNumber, getString } from "../config/settings.js";
import { retryDelayMs, shouldRetry } from "./retry.js";

export interface OutgoingMail {
  to: string;
  subject: string;
  body: string;
}

export async function deliver(
  mail: OutgoingMail,
  send: (host: string, port: number, from: string, mail: OutgoingMail) => Promise<void>,
  attempt = 1,
): Promise<void> {
  try {
    await send(getString("SMTP_HOST"), getNumber("SMTP_PORT"), getString("SENDER_ADDRESS"), mail);
  } catch (err) {
    if (!shouldRetry(attempt)) throw err;
    const delay = retryDelayMs();
    console.warn(`delivery to ${mail.to} failed, retrying in ${delay}ms`);
    setTimeout(() => void deliver(mail, send, attempt + 1), delay);
  }
}
TS

git add -A
git commit -q -m "Mail relay worker with retries"

# Uncommitted: one typed accessor instead of a getter per type.
cat > src/config/settings.ts <<'TS'
import { readFileSync } from "node:fs";

const SETTINGS_FILE = process.env.WORKER_SETTINGS ?? new URL("../../config/worker.env", import.meta.url);

function load(): Record<string, string> {
  const values: Record<string, string> = {};
  for (const line of readFileSync(SETTINGS_FILE, "utf8").split("\n")) {
    const match = /^([A-Z0-9_]+)=(.*)$/.exec(line.trim());
    if (match) values[match[1]] = match[2];
  }
  return values;
}

const store = load();

// One accessor for every setting; callers say which type they expect.
export function getSetting<T>(key: string): T {
  if (!(key in store)) throw new Error(`missing setting ${key}`);
  return store[key] as T;
}
TS

cat > src/delivery/retry.ts <<'TS'
import { getSetting } from "../config/settings.js";

// The provider rate-limits bursts, so every retry waits at least half a second
// beyond the configured delay.
export function retryDelayMs(): number {
  return getSetting<number>("RETRY_DELAY_MS") + 500;
}

export function shouldRetry(attempt: number): boolean {
  return attempt < getSetting<number>("MAX_ATTEMPTS");
}
TS

cat > src/delivery/worker.ts <<'TS'
import { getSetting } from "../config/settings.js";
import { retryDelayMs, shouldRetry } from "./retry.js";

export interface OutgoingMail {
  to: string;
  subject: string;
  body: string;
}

export async function deliver(
  mail: OutgoingMail,
  send: (host: string, port: number, from: string, mail: OutgoingMail) => Promise<void>,
  attempt = 1,
): Promise<void> {
  try {
    await send(
      getSetting<string>("SMTP_HOST"),
      getSetting<number>("SMTP_PORT"),
      getSetting<string>("SENDER_ADDRESS"),
      mail,
    );
  } catch (err) {
    if (!shouldRetry(attempt)) throw err;
    const delay = retryDelayMs();
    console.warn(`delivery to ${mail.to} failed, retrying in ${delay}ms`);
    setTimeout(() => void deliver(mail, send, attempt + 1), delay);
  }
}
TS
