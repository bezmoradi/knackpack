#!/bin/bash
# A timesheet service written partly in JavaScript with JSDoc types (allowJs,
# checkJs), plus an uncommitted JS overtime module and a TypeScript caller.
set -euo pipefail
git init -q -b main
git config user.name "Sofia Lindgren"
git config user.email "sofia.lindgren@example.com"
mkdir -p src/timesheets

cat > package.json <<'JSON'
{
  "name": "shiftbook-timesheets",
  "version": "2.1.3",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p ."
  },
  "devDependencies": {
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
    "allowJs": true,
    "checkJs": true,
    "strict": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > CONTRIBUTING.md <<'MD'
# Contributing

The service mixes TypeScript and JavaScript. Both are type-checked by `tsc`
(`allowJs` and `checkJs`), so JavaScript files must carry accurate JSDoc
types. New files may be either; there is no plan to convert the JavaScript.
MD

cat > src/timesheets/types.ts <<'TS'
export interface TimeEntry {
  employeeId: string;
  // ISO date of the shift, for example "2026-11-02".
  date: string;
  minutes: number;
}

export interface Employee {
  id: string;
  name: string;
  hourlyRateCents: number;
}
TS

cat > src/timesheets/hours.js <<'JS'
// @ts-check

/** @typedef {import("./types.js").TimeEntry} TimeEntry */

/**
 * Total minutes worked per employee.
 * @param {readonly TimeEntry[]} entries
 * @returns {Map<string, number>}
 */
export function minutesByEmployee(entries) {
  /** @type {Map<string, number>} */
  const totals = new Map();
  for (const entry of entries) {
    totals.set(entry.employeeId, (totals.get(entry.employeeId) ?? 0) + entry.minutes);
  }
  return totals;
}
JS

cat > src/report.ts <<'TS'
import { minutesByEmployee } from "./timesheets/hours.js";
import type { Employee, TimeEntry } from "./timesheets/types.js";

export function hoursReport(employees: readonly Employee[], entries: readonly TimeEntry[]): string[] {
  const totals = minutesByEmployee(entries);
  return employees.map((e) => `${e.name}: ${((totals.get(e.id) ?? 0) / 60).toFixed(2)} h`);
}
TS

git add -A
git commit -q -m "Weekly hours report"

# Uncommitted: overtime split and weekly pay.
cat > src/timesheets/overtime.js <<'JS'
// @ts-check

/**
 * Splits a week's minutes into regular time and overtime.
 * @param {number} weekMinutes total minutes one employee worked in the week
 * @param {number} [weeklyLimitHours=40] hours paid at the regular rate
 * @returns {{ regularMinutes: number, overtimeMinutes: number }}
 */
export function splitOvertime(weekMinutes, weeklyLimitHours = 40) {
  const limitMinutes = weeklyLimitHours * 60;
  const regularMinutes = Math.min(weekMinutes, limitMinutes);
  return { regularMinutes, overtimeMinutes: weekMinutes - regularMinutes };
}

/**
 * Pay in cents, with overtime at one and a half times the hourly rate.
 * @param {{ regularMinutes: number, overtimeMinutes: number }} split
 * @param {number} hourlyRateCents
 * @returns {number}
 */
export function payCents(split, hourlyRateCents) {
  const regular = (split.regularMinutes * hourlyRateCents) / 60;
  const overtime = (split.overtimeMinutes * hourlyRateCents * 1.5) / 60;
  return Math.round(regular + overtime);
}
JS

cat > src/payroll.ts <<'TS'
import { minutesByEmployee } from "./timesheets/hours.js";
import { payCents, splitOvertime } from "./timesheets/overtime.js";
import type { Employee, TimeEntry } from "./timesheets/types.js";

export interface PayLine {
  employeeId: string;
  regularMinutes: number;
  overtimeMinutes: number;
  payCents: number;
}

// One week's entries in, one pay line per employee out.
export function weeklyPayroll(employees: readonly Employee[], weekEntries: readonly TimeEntry[]): PayLine[] {
  const totals = minutesByEmployee(weekEntries);
  return employees.map((employee) => {
    const split = splitOvertime(totals.get(employee.id) ?? 0);
    return { employeeId: employee.id, ...split, payCents: payCents(split, employee.hourlyRateCents) };
  });
}
TS
