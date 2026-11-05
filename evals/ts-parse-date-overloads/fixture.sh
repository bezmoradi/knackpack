#!/bin/bash
# A meeting-room booking service, plus an uncommitted parseDate helper whose
# overloads promise a Date while the implementation returns null on bad input.
set -euo pipefail
git init -q -b main
git config user.name "Aiko Tanaka"
git config user.email "aiko.tanaka@example.com"
mkdir -p src/bookings src/lib

cat > package.json <<'JSON'
{
  "name": "roomdesk-api",
  "version": "1.12.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/server.js"
  },
  "devDependencies": {
    "@types/node": "^22.10.2",
    "typescript": "^5.7.2"
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

cat > src/bookings/types.ts <<'TS'
export interface BookingRequest {
  roomId: string;
  // Sent by the booking form: the value of an <input type="datetime-local">,
  // which is an empty string when the user clears the field.
  start: string;
  // The same kind of form value, or a Unix timestamp in milliseconds when the
  // booking comes from the calendar sync.
  end: string | number;
  organizer: string;
}

export interface Booking {
  id: string;
  roomId: string;
  startsAt: string;
  endsAt: string;
  organizer: string;
}
TS

cat > src/bookings/store.ts <<'TS'
import type { Booking } from "./types.js";

const bookings: Booking[] = [];
let nextId = 1;

export function saveBooking(booking: Omit<Booking, "id">): Booking {
  const saved = { id: `bk_${nextId++}`, ...booking };
  bookings.push(saved);
  return saved;
}

export function bookingsForRoom(roomId: string): Booking[] {
  return bookings.filter((b) => b.roomId === roomId);
}
TS

cat > src/bookings/createBooking.ts <<'TS'
import { saveBooking } from "./store.js";
import type { Booking, BookingRequest } from "./types.js";

export class BookingError extends Error {}

export function createBooking(request: BookingRequest): Booking {
  const startsAt = new Date(request.start);
  const endsAt = new Date(request.end);
  if (Number.isNaN(startsAt.getTime()) || Number.isNaN(endsAt.getTime())) {
    throw new BookingError("start and end must be valid dates");
  }
  if (endsAt <= startsAt) {
    throw new BookingError("a booking must end after it starts");
  }
  return saveBooking({
    roomId: request.roomId,
    startsAt: startsAt.toISOString(),
    endsAt: endsAt.toISOString(),
    organizer: request.organizer,
  });
}
TS

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { BookingError, createBooking } from "./bookings/createBooking.js";
import type { BookingRequest } from "./bookings/types.js";

createServer((req, res) => {
  if (req.method !== "POST" || req.url !== "/bookings") {
    res.writeHead(404).end();
    return;
  }
  let body = "";
  req.on("data", (chunk) => (body += chunk));
  req.on("end", () => {
    try {
      const booking = createBooking(JSON.parse(body) as BookingRequest);
      res.writeHead(201, { "content-type": "application/json" }).end(JSON.stringify(booking));
    } catch (err) {
      const status = err instanceof BookingError ? 400 : 500;
      res.writeHead(status).end(err instanceof Error ? err.message : "error");
    }
  });
}).listen(Number(process.env.PORT ?? 3200));
TS

git add -A
git commit -q -m "Room bookings endpoint"

# Uncommitted: a shared parseDate helper, used by the booking flow.
cat > src/lib/parseDate.ts <<'TS'
/**
 * Parses a date from a form value (an ISO or datetime-local string) or from
 * a Unix timestamp in milliseconds.
 */
export function parseDate(input: string): Date;
export function parseDate(input: number): Date;
export function parseDate(input: string | number): Date | null {
  if (typeof input === "number") {
    return new Date(input);
  }
  const trimmed = input.trim();
  if (trimmed === "") {
    return null;
  }
  const date = new Date(trimmed);
  return Number.isNaN(date.getTime()) ? null : date;
}
TS

cat > src/bookings/createBooking.ts <<'TS'
import { parseDate } from "../lib/parseDate.js";
import { saveBooking } from "./store.js";
import type { Booking, BookingRequest } from "./types.js";

export class BookingError extends Error {}

export function createBooking(request: BookingRequest): Booking {
  const startsAt = parseDate(request.start).toISOString();
  const endsAt =
    typeof request.end === "number"
      ? parseDate(request.end).toISOString()
      : parseDate(request.end).toISOString();
  if (endsAt <= startsAt) {
    throw new BookingError("a booking must end after it starts");
  }
  return saveBooking({
    roomId: request.roomId,
    startsAt,
    endsAt,
    organizer: request.organizer,
  });
}
TS
