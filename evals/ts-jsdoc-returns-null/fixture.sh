#!/bin/bash
# A JavaScript subscription-box service type-checked with checkJs, plus an
# uncommitted findCustomer whose JSDoc promises a Customer but can give null.
set -euo pipefail
git init -q -b main
git config user.name "Hannah Okafor"
git config user.email "hannah.okafor@example.com"
mkdir -p src/http src/customers src/renewals

cat > package.json <<'JSON'
{
  "name": "crate-club-renewals",
  "version": "1.9.1",
  "private": true,
  "type": "module",
  "scripts": {
    "typecheck": "tsc -p .",
    "renewals": "node src/renewals/run.js"
  },
  "devDependencies": {
    "@types/node": "^22.14.1",
    "typescript": "^5.8.3"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "lib": ["es2022", "dom"],
    "allowJs": true,
    "checkJs": true,
    "noEmit": true,
    "strict": true
  },
  "include": ["src"]
}
JSON

cat > src/http/getJson.js <<'JS'
// @ts-check

const API = "https://crm.crateclub.example.com/api";

/**
 * GETs a path on the CRM API and parses the JSON body.
 * Resolves to null when the CRM answers 404; throws on any other error status.
 * @param {string} path
 * @returns {Promise<any>}
 */
export async function getJson(path) {
  const res = await fetch(`${API}${path}`);
  if (res.status === 404) return null;
  if (!res.ok) throw new Error(`CRM ${path} failed: ${res.status}`);
  return res.json();
}
JS

cat > src/customers/types.js <<'JS'
// @ts-check

/**
 * @typedef {object} Customer
 * @property {string} id
 * @property {string} name
 * @property {string} email
 * @property {string} plan
 * @property {string} renewsOn ISO date
 */

export {};
JS

cat > src/customers/listCustomers.js <<'JS'
// @ts-check
import { getJson } from "../http/getJson.js";

/** @typedef {import("./types.js").Customer} Customer */

/**
 * Customers whose subscription renews on the given day.
 * @param {string} date ISO date
 * @returns {Promise<Customer[]>}
 */
export async function customersRenewingOn(date) {
  const body = await getJson(`/customers?renewsOn=${encodeURIComponent(date)}`);
  return body.customers;
}
JS

cat > src/renewals/mailer.js <<'JS'
// @ts-check

/**
 * @param {{ to: string, subject: string, text: string }} message
 */
export async function sendMail(message) {
  console.log(`mail to ${message.to}: ${message.subject}`);
}
JS

cat > src/renewals/run.js <<'JS'
// @ts-check
import { customersRenewingOn } from "../customers/listCustomers.js";
import { sendMail } from "./mailer.js";

const date = process.argv[2] ?? new Date().toISOString().slice(0, 10);
for (const customer of await customersRenewingOn(date)) {
  await sendMail({
    to: customer.email,
    subject: "Your crate renews soon",
    text: `Hi ${customer.name}, your ${customer.plan} crate renews on ${customer.renewsOn}.`,
  });
}
JS

git add -A
git commit -q -m "Renewal reminder run"

# Uncommitted: look up one customer, for reminders support resends by hand.
cat > src/customers/findCustomer.js <<'JS'
// @ts-check
import { getJson } from "../http/getJson.js";

/** @typedef {import("./types.js").Customer} Customer */

/**
 * Fetches one customer by id from the CRM.
 * @param {string} id
 * @returns {Promise<Customer>}
 */
export async function findCustomer(id) {
  return getJson(`/customers/${encodeURIComponent(id)}`);
}
JS

cat > src/renewals/resend.js <<'JS'
// @ts-check
import { findCustomer } from "../customers/findCustomer.js";
import { sendMail } from "./mailer.js";

/**
 * Resends the renewal reminder to each customer id support pastes in.
 * @param {string[]} ids
 * @returns {Promise<number>} how many reminders were sent
 */
export async function resendReminders(ids) {
  let sent = 0;
  for (const id of ids) {
    const customer = await findCustomer(id);
    await sendMail({
      to: customer.email,
      subject: "Your crate renews soon",
      text: `Hi ${customer.name}, your ${customer.plan} crate renews on ${customer.renewsOn}.`,
    });
    sent += 1;
  }
  return sent;
}
JS

cat > src/renewals/resendCli.js <<'JS'
// @ts-check
import { resendReminders } from "./resend.js";

// Usage: node src/renewals/resendCli.js cus_123 cus_456 ...
const count = await resendReminders(process.argv.slice(2));
console.log(`resent ${count} reminder(s)`);
JS
