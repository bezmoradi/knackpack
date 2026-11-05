#!/bin/bash
# A rental listings admin whose committed legacy importer is full of any and a
# @ts-ignore, plus an uncommitted, correct pageSize parameter for paginate.
set -euo pipefail
git init -q -b main
git config user.name "Grace Okafor"
git config user.email "grace.okafor@example.com"
mkdir -p src/legacy
cat > package.json <<'JSON'
{
  "name": "lettings-admin",
  "version": "3.0.4",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p ."
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
    "target": "ES2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "rootDir": "src",
    "outDir": "dist",
    "types": ["node"]
  },
  "include": ["src"]
}
JSON
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > src/types.ts <<'TS'
export interface Listing {
  ref: string;
  address: string;
  bedrooms: number;
  rentCents: number;
  available: boolean;
}
TS
cat > src/pagination.ts <<'TS'
export interface Page<T> {
  items: T[];
  page: number;
  pageCount: number;
  total: number;
}

const PAGE_SIZE = 25;

/** Returns the requested 1-based page, clamped to the pages that exist. */
export function paginate<T>(items: readonly T[], page: number): Page<T> {
  const pageCount = Math.max(1, Math.ceil(items.length / PAGE_SIZE));
  const requested = Number.isFinite(page) ? Math.trunc(page) : 1;
  const current = Math.min(Math.max(1, requested), pageCount);
  const start = (current - 1) * PAGE_SIZE;
  return { items: items.slice(start, start + PAGE_SIZE), page: current, pageCount, total: items.length };
}
TS
cat > src/listings-page.ts <<'TS'
import { paginate } from "./pagination.js";
import type { Listing } from "./types.js";

const money = new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" });

export function listingsTable(listings: readonly Listing[], page: number): string {
  const result = paginate(listings, page);
  const rows = result.items.map(
    (listing) => `${listing.ref}\t${listing.bedrooms} bed\t${money.format(listing.rentCents / 100)}\t${listing.address}`,
  );
  return [...rows, `Page ${result.page} of ${result.pageCount} (${result.total} listings)`].join("\n");
}
TS
cat > src/export-report.ts <<'TS'
import { paginate } from "./pagination.js";
import type { Listing } from "./types.js";

function csvCell(value: string | number | boolean): string {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

/** One chunk of the nightly CSV export for the letting agents' portal. */
export function exportChunk(listings: readonly Listing[], chunk: number): { csv: string; more: boolean } {
  const result = paginate(listings, chunk);
  const lines = result.items.map((listing) =>
    [listing.ref, listing.address, listing.bedrooms, listing.rentCents, listing.available].map(csvCell).join(","),
  );
  return { csv: lines.join("\n"), more: result.page < result.pageCount };
}
TS
cat > src/legacy/geo.ts <<'TS'
// Ported as-is from the old PHP admin. Typed properly when the importer is rewritten.
export function toLatLng(lat: any, lng: any): any {
  return { lat: parseFloat(lat), lng: parseFloat(lng) };
}

export function distanceKm(a: any, b: any) {
  const rad = (deg: any) => (deg * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.asin(Math.sqrt(h));
}
TS
cat > src/legacy/import-listings.ts <<'TS'
// Reads rows from the old PHP admin's CSV export. Ported as-is; to be rewritten
// with real types once the old admin is switched off.
import { toLatLng } from "./geo.js";

export function parseLegacyRow(row: any): any {
  const out: any = {};
  out.ref = row.REF;
  out.address = [row.ADDR1, row.ADDR2, row.TOWN].filter(Boolean).join(", ");
  out.bedrooms = parseInt(row.BEDS);
  out.rentCents = Math.round(parseFloat(String(row.RENT).replace(",", "")) * 100);
  out.available = row.STATUS == "AVAILABLE";
  // @ts-ignore the old export adds a zone code we don't use yet
  out.location = toLatLng(row.LAT, row.LNG, row.ZONE);
  return out;
}

export function parseLegacyExport(rows: any[]) {
  return rows.map(parseLegacyRow).filter((listing: any) => listing.ref);
}
TS
git add -A
git commit -q -m "Listings table and nightly export share one paginate helper"

# Uncommitted: let callers choose the page size.
cat > src/pagination.ts <<'TS'
export interface Page<T> {
  items: T[];
  page: number;
  pageCount: number;
  total: number;
}

const DEFAULT_PAGE_SIZE = 25;

/** Returns the requested 1-based page, clamped to the pages that exist. */
export function paginate<T>(items: readonly T[], page: number, pageSize = DEFAULT_PAGE_SIZE): Page<T> {
  if (!Number.isInteger(pageSize) || pageSize < 1) {
    throw new RangeError(`pageSize must be a positive whole number, got ${pageSize}`);
  }
  const pageCount = Math.max(1, Math.ceil(items.length / pageSize));
  const requested = Number.isFinite(page) ? Math.trunc(page) : 1;
  const current = Math.min(Math.max(1, requested), pageCount);
  const start = (current - 1) * pageSize;
  return { items: items.slice(start, start + pageSize), page: current, pageCount, total: items.length };
}
TS
cat > src/listings-page.ts <<'TS'
import { paginate } from "./pagination.js";
import type { Listing } from "./types.js";

// The lettings team scans the whole table each morning; 50 rows saves them half the clicks.
const TABLE_PAGE_SIZE = 50;

const money = new Intl.NumberFormat("en-GB", { style: "currency", currency: "GBP" });

export function listingsTable(listings: readonly Listing[], page: number): string {
  const result = paginate(listings, page, TABLE_PAGE_SIZE);
  const rows = result.items.map(
    (listing) => `${listing.ref}\t${listing.bedrooms} bed\t${money.format(listing.rentCents / 100)}\t${listing.address}`,
  );
  return [...rows, `Page ${result.page} of ${result.pageCount} (${result.total} listings)`].join("\n");
}
TS
cat > src/export-report.ts <<'TS'
import { paginate } from "./pagination.js";
import type { Listing } from "./types.js";

// The agents' portal accepts up to 500 rows per upload; bigger chunks mean fewer requests.
const EXPORT_CHUNK_SIZE = 500;

function csvCell(value: string | number | boolean): string {
  const text = String(value);
  return /[",\n]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

/** One chunk of the nightly CSV export for the letting agents' portal. */
export function exportChunk(listings: readonly Listing[], chunk: number): { csv: string; more: boolean } {
  const result = paginate(listings, chunk, EXPORT_CHUNK_SIZE);
  const lines = result.items.map((listing) =>
    [listing.ref, listing.address, listing.bedrooms, listing.rentCents, listing.available].map(csvCell).join(","),
  );
  return { csv: lines.join("\n"), more: result.page < result.pageCount };
}
TS
