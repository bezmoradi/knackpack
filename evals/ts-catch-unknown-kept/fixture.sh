#!/bin/bash
# A dental clinic's appointment reminder worker, plus an uncommitted change that
# loads reminder templates from a JSON file, handling unknown values and errors.
set -euo pipefail
git init -q -b main
git config user.name "Mateo Herrera"
git config user.email "mateo.herrera@example.com"
mkdir -p src/config src/reminders config

cat > package.json <<'JSON'
{
  "name": "brightsmile-reminders",
  "version": "1.6.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/worker.js"
  },
  "devDependencies": {
    "@types/node": "^22.13.10",
    "typescript": "^5.8.2"
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

cat > src/reminders/types.ts <<'TS'
export interface ReminderTemplate {
  id: string;
  channel: "sms" | "email";
  hoursBefore: number;
  body: string;
}

export interface Appointment {
  patientName: string;
  phone: string;
  email: string;
  startsAt: Date;
}
TS

cat > src/reminders/templates.ts <<'TS'
import type { ReminderTemplate } from "./types.js";

export const TEMPLATES: ReminderTemplate[] = [
  { id: "day-before", channel: "email", hoursBefore: 24, body: "Hi {name}, see you tomorrow at {time}." },
  { id: "two-hours", channel: "sms", hoursBefore: 2, body: "Reminder: your appointment is at {time}." },
];
TS

cat > src/reminders/render.ts <<'TS'
import type { Appointment, ReminderTemplate } from "./types.js";

export function renderReminder(template: ReminderTemplate, appointment: Appointment): string {
  const time = appointment.startsAt.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
  return template.body.replaceAll("{name}", appointment.patientName).replaceAll("{time}", time);
}

export function dueTemplates(templates: ReminderTemplate[], appointment: Appointment, now: Date): ReminderTemplate[] {
  const hoursUntil = (appointment.startsAt.getTime() - now.getTime()) / 3_600_000;
  return templates.filter((t) => hoursUntil <= t.hoursBefore && hoursUntil > t.hoursBefore - 1);
}
TS

cat > src/worker.ts <<'TS'
import { dueTemplates, renderReminder } from "./reminders/render.js";
import { TEMPLATES } from "./reminders/templates.js";
import type { Appointment } from "./reminders/types.js";

const appointments: Appointment[] = [
  { patientName: "Noor", phone: "+441234567890", email: "noor@example.com", startsAt: new Date(Date.now() + 90 * 60_000) },
];

for (const appointment of appointments) {
  for (const template of dueTemplates(TEMPLATES, appointment, new Date())) {
    console.log(`[${template.channel}] ${renderReminder(template, appointment)}`);
  }
}
TS

git add -A
git commit -q -m "Reminder worker with built-in templates"

# Uncommitted: templates come from config/reminder-templates.json, so the
# front desk can edit wording without a deploy.
cat > config/reminder-templates.json <<'JSON'
{
  "templates": [
    { "id": "day-before", "channel": "email", "hoursBefore": 24, "body": "Hi {name}, see you tomorrow at {time}. Reply to this email to rearrange." },
    { "id": "two-hours", "channel": "sms", "hoursBefore": 2, "body": "BrightSmile: your appointment is at {time}." }
  ]
}
JSON

cat > src/config/parseJson.ts <<'TS'
// JSON.parse returns any; callers get unknown and must check the shape.
export function parseJson(text: string): unknown {
  return JSON.parse(text);
}
TS

cat > src/config/reminderTemplates.ts <<'TS'
import { readFile } from "node:fs/promises";
import type { ReminderTemplate } from "../reminders/types.js";
import { parseJson } from "./parseJson.js";

export class TemplateConfigError extends Error {
  constructor(message: string, options?: { cause?: unknown }) {
    super(message, options);
    this.name = "TemplateConfigError";
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isReminderTemplate(value: unknown): value is ReminderTemplate {
  return (
    isRecord(value) &&
    typeof value.id === "string" &&
    (value.channel === "sms" || value.channel === "email") &&
    typeof value.hoursBefore === "number" &&
    Number.isFinite(value.hoursBefore) &&
    value.hoursBefore > 0 &&
    typeof value.body === "string"
  );
}

function isErrnoException(err: unknown): err is NodeJS.ErrnoException {
  return err instanceof Error && "code" in err;
}

export async function loadReminderTemplates(path: string): Promise<ReminderTemplate[]> {
  let text: string;
  try {
    text = await readFile(path, "utf8");
  } catch (err: unknown) {
    if (isErrnoException(err) && err.code === "ENOENT") {
      throw new TemplateConfigError(`reminder templates not found at ${path}`, { cause: err });
    }
    throw err;
  }

  let data: unknown;
  try {
    data = parseJson(text);
  } catch (err: unknown) {
    const reason = err instanceof SyntaxError ? err.message : String(err);
    throw new TemplateConfigError(`${path} is not valid JSON: ${reason}`, { cause: err });
  }

  if (!isRecord(data) || !Array.isArray(data.templates)) {
    throw new TemplateConfigError(`${path} must contain an object with a "templates" array`);
  }
  const entries: unknown[] = data.templates;
  const templates: ReminderTemplate[] = [];
  entries.forEach((entry, index) => {
    if (!isReminderTemplate(entry)) {
      throw new TemplateConfigError(
        `${path}: templates[${index}] needs an id, a channel of "sms" or "email", a positive hoursBefore and a body`,
      );
    }
    templates.push(entry);
  });
  return templates;
}
TS

cat > src/worker.ts <<'TS'
import { loadReminderTemplates, TemplateConfigError } from "./config/reminderTemplates.js";
import { dueTemplates, renderReminder } from "./reminders/render.js";
import type { Appointment, ReminderTemplate } from "./reminders/types.js";

const templatesPath = process.env.REMINDER_TEMPLATES ?? "config/reminder-templates.json";

let templates: ReminderTemplate[];
try {
  templates = await loadReminderTemplates(templatesPath);
} catch (err: unknown) {
  if (err instanceof TemplateConfigError) {
    console.error(`cannot start: ${err.message}`);
    process.exit(1);
  }
  throw err;
}

const appointments: Appointment[] = [
  { patientName: "Noor", phone: "+441234567890", email: "noor@example.com", startsAt: new Date(Date.now() + 90 * 60_000) },
];

for (const appointment of appointments) {
  for (const template of dueTemplates(templates, appointment, new Date())) {
    console.log(`[${template.channel}] ${renderReminder(template, appointment)}`);
  }
}
TS

rm src/reminders/templates.ts
