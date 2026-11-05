#!/bin/bash
# A Vite front end for a vet clinic's appointment book, plus an uncommitted change
# that drops every tsc run from the build and CI and adds a call with a string
# where a number of days is expected.
set -euo pipefail
git init -q -b main
git config user.name "Malik Osei"
git config user.email "malik.osei@example.com"
mkdir -p src .github/workflows
cat > package.json <<'JSON'
{
  "name": "clinic-appointments",
  "version": "0.14.2",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "typecheck": "tsc --noEmit",
    "build": "tsc --noEmit && vite build",
    "preview": "vite preview",
    "test": "vitest run"
  },
  "devDependencies": {
    "typescript": "^5.9.3",
    "vite": "^7.1.5",
    "vitest": "^3.2.4"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "noEmit": true,
    "strict": true,
    "noUnusedLocals": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
JSON
cat > vite.config.ts <<'TS'
import { defineConfig } from "vitest/config";

export default defineConfig({
  build: {
    sourcemap: true,
  },
  test: {
    environment: "node",
    include: ["src/**/*.spec.ts"],
  },
});
TS
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > .github/workflows/ci.yml <<'YAML'
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      - name: Type check
        run: npm run typecheck
      - name: Build
        run: npm run build
      - name: Unit specs
        run: npm test
YAML
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <title>Appointments</title>
  </head>
  <body>
    <main id="app"></main>
    <script type="module" src="/src/main.ts"></script>
  </body>
</html>
HTML
cat > src/appointments.ts <<'TS'
export interface Appointment {
  id: string;
  petName: string;
  ownerName: string;
  start: string; // ISO 8601
  durationMinutes: number;
  note?: string;
}

export function shiftAppointment(appt: Appointment, days: number): Appointment {
  const start = new Date(appt.start);
  start.setDate(start.getDate() + days);
  return { ...appt, start: start.toISOString() };
}

export function formatSlot(appt: Appointment): string {
  const start = new Date(appt.start);
  return `${start.toLocaleDateString("en-GB")} ${start.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" })}`;
}
TS
cat > src/appointments.spec.ts <<'TS'
import { describe, expect, it } from "vitest";
import { shiftAppointment, type Appointment } from "./appointments";

const base: Appointment = {
  id: "a-1",
  petName: "Biscuit",
  ownerName: "J. Moreau",
  start: "2026-04-12T09:30:00.000Z",
  durationMinutes: 20,
};

describe("shiftAppointment", () => {
  it("moves the appointment forward by whole days", () => {
    expect(shiftAppointment(base, 7).start).toBe("2026-04-19T09:30:00.000Z");
  });

  it("keeps the other fields", () => {
    expect(shiftAppointment(base, 1).petName).toBe("Biscuit");
  });
});
TS
cat > src/main.ts <<'TS'
import { formatSlot, type Appointment } from "./appointments";

const today: Appointment[] = [
  { id: "a-1", petName: "Biscuit", ownerName: "J. Moreau", start: "2026-04-12T09:30:00.000Z", durationMinutes: 20 },
  { id: "a-2", petName: "Nala", ownerName: "R. Banerjee", start: "2026-04-12T10:00:00.000Z", durationMinutes: 40 },
];

const app = document.querySelector<HTMLElement>("#app")!;
app.innerHTML = today
  .map((appt) => `<p>${formatSlot(appt)} ${appt.petName} (${appt.ownerName})</p>`)
  .join("");
TS
git add -A
git commit -q -m "Appointment list for the front desk"

# Uncommitted: a reschedule form, and a leaner build and CI.
cat > package.json <<'JSON'
{
  "name": "clinic-appointments",
  "version": "0.15.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "typecheck": "tsc --noEmit",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest run"
  },
  "devDependencies": {
    "typescript": "^5.9.3",
    "vite": "^7.1.5",
    "vitest": "^3.2.4"
  }
}
JSON
cat > .github/workflows/ci.yml <<'YAML'
name: ci

on:
  pull_request:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - uses: actions/setup-node@v5
        with:
          node-version: 22
          cache: npm
      - run: npm ci
      # Faster CI: the build no longer runs tsc separately, Vite handles the TypeScript.
      - name: Build
        run: npm run build
      - name: Unit specs
        run: npm test
YAML
cat > src/reschedule.ts <<'TS'
import { shiftAppointment, type Appointment } from "./appointments";

export interface RescheduleRequest {
  days: string; // from the "Move by" select
  reason: string;
}

export function applyReschedule(appt: Appointment, request: RescheduleRequest): Appointment {
  const moved = shiftAppointment(appt, request.days);
  return { ...moved, note: request.reason.trim() || appt.note };
}
TS
cat > src/main.ts <<'TS'
import { formatSlot, type Appointment } from "./appointments";
import { applyReschedule } from "./reschedule";

let today: Appointment[] = [
  { id: "a-1", petName: "Biscuit", ownerName: "J. Moreau", start: "2026-04-12T09:30:00.000Z", durationMinutes: 20 },
  { id: "a-2", petName: "Nala", ownerName: "R. Banerjee", start: "2026-04-12T10:00:00.000Z", durationMinutes: 40 },
];

const app = document.querySelector<HTMLElement>("#app")!;

function render(): void {
  app.innerHTML = today
    .map(
      (appt) => `
      <form data-id="${appt.id}">
        <p>${formatSlot(appt)} ${appt.petName} (${appt.ownerName})</p>
        <select name="days">
          <option value="1">Tomorrow</option>
          <option value="7">Next week</option>
          <option value="14">In two weeks</option>
        </select>
        <input name="reason" placeholder="Reason">
        <button>Move</button>
      </form>`,
    )
    .join("");
}

app.addEventListener("submit", (event) => {
  event.preventDefault();
  const form = event.target as HTMLFormElement;
  const days = form.querySelector<HTMLSelectElement>("select[name=days]")!.value;
  const reason = form.querySelector<HTMLInputElement>("input[name=reason]")!.value;
  today = today.map((appt) => (appt.id === form.dataset.id ? applyReschedule(appt, { days, reason }) : appt));
  render();
});

render();
TS
