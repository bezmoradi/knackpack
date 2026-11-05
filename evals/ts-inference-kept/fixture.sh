#!/bin/bash
# A parcel shipping quote tool, plus an uncommitted rate calculator that leans
# on inference for locals and internal helpers, as CONTRIBUTING.md allows.
set -euo pipefail
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi.mensah@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "parcel-quotes",
  "version": "0.6.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "quote": "node dist/main.js"
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
    "noUncheckedIndexedAccess": true,
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
cat > CONTRIBUTING.md <<'MD'
# Contributing

## TypeScript style

- Exported functions declare their return types, so a change inside a function
  can't silently change what callers receive.
- Inside a module, let the compiler infer: don't annotate locals or internal
  helpers when the inferred type is what you mean.
- Prefer `as const` and `satisfies` for lookup tables and configuration over
  wide annotations that throw away the literal types.
- Amounts are integer cents; round once, at the end of a calculation.
MD
cat > src/types.ts <<'TS'
export type ServiceLevel = "standard" | "express" | "overnight";

export interface Parcel {
  weightGrams: number;
  lengthCm: number;
  widthCm: number;
  heightCm: number;
  destinationPostcode: string;
}
TS
cat > src/zones.ts <<'TS'
// Postcode prefixes served by partner carriers, which add a remote-area charge.
const REMOTE_PREFIXES = ["HS", "IV", "KW", "ZE", "PA20", "PA41"] as const;

export function isRemotePostcode(postcode: string): boolean {
  const normalized = postcode.replace(/\s+/g, "").toUpperCase();
  return REMOTE_PREFIXES.some((prefix) => normalized.startsWith(prefix));
}
TS
cat > src/main.ts <<'TS'
import { isRemotePostcode } from "./zones.js";

for (const postcode of ["EH1 1YZ", "HS1 2AA"]) {
  console.log(`${postcode}: ${isRemotePostcode(postcode) ? "remote" : "mainland"}`);
}
TS
git add -A
git commit -q -m "Remote postcode lookup"

# Uncommitted: price quotes.
cat > src/types.ts <<'TS'
export type ServiceLevel = "standard" | "express" | "overnight";

export interface Parcel {
  weightGrams: number;
  lengthCm: number;
  widthCm: number;
  heightCm: number;
  destinationPostcode: string;
}

export interface RateConfig {
  currency: string;
  fuelSurchargePercent: number;
  remoteSurchargeCents: number;
}

export type Quote =
  | { ok: true; service: ServiceLevel; chargeableGrams: number; totalCents: number }
  | { ok: false; reason: "too-heavy" };
TS
cat > src/rates.ts <<'TS'
import type { Parcel, Quote, RateConfig, ServiceLevel } from "./types.js";
import { isRemotePostcode } from "./zones.js";

const SERVICE_MULTIPLIER = {
  standard: 1,
  express: 1.6,
  overnight: 2.4,
} as const satisfies Record<ServiceLevel, number>;

// Each band covers parcels up to and including upToGrams.
const WEIGHT_BANDS = [
  { upToGrams: 500, baseCents: 450 },
  { upToGrams: 2_000, baseCents: 790 },
  { upToGrams: 10_000, baseCents: 1_490 },
  { upToGrams: 30_000, baseCents: 2_990 },
] as const;

export const rateConfig = {
  currency: "GBP",
  fuelSurchargePercent: 7.5,
  remoteSurchargeCents: 600,
} satisfies RateConfig;

// Carriers bill the larger of actual and volumetric weight (length x width x height / 5000 per kg).
function volumetricGrams(parcel: Parcel) {
  return Math.ceil((parcel.lengthCm * parcel.widthCm * parcel.heightCm) / 5);
}

function chargeableGrams(parcel: Parcel) {
  return Math.max(parcel.weightGrams, volumetricGrams(parcel));
}

function bandFor(grams: number) {
  return WEIGHT_BANDS.find((band) => grams <= band.upToGrams);
}

export function quoteParcel(parcel: Parcel, service: ServiceLevel): Quote {
  const grams = chargeableGrams(parcel);
  const band = bandFor(grams);
  if (!band) return { ok: false, reason: "too-heavy" };

  const base = band.baseCents * SERVICE_MULTIPLIER[service];
  const withFuel = base * (1 + rateConfig.fuelSurchargePercent / 100);
  const remote = isRemotePostcode(parcel.destinationPostcode) ? rateConfig.remoteSurchargeCents : 0;
  return { ok: true, service, chargeableGrams: grams, totalCents: Math.round(withFuel + remote) };
}

export function quoteAllServices(parcel: Parcel): Quote[] {
  const services = Object.keys(SERVICE_MULTIPLIER) as ServiceLevel[];
  return services.map((service) => quoteParcel(parcel, service));
}

const money = new Intl.NumberFormat("en-GB", { style: "currency", currency: rateConfig.currency });

export function formatQuote(quote: Quote): string {
  if (!quote.ok) return "Too heavy to ship";
  const kg = (quote.chargeableGrams / 1000).toFixed(1);
  return `${quote.service.padEnd(10)} ${money.format(quote.totalCents / 100)} (${kg} kg chargeable)`;
}
TS
cat > src/main.ts <<'TS'
import { formatQuote, quoteAllServices } from "./rates.js";
import type { Parcel } from "./types.js";

const parcels: Parcel[] = [
  { weightGrams: 1_200, lengthCm: 30, widthCm: 20, heightCm: 10, destinationPostcode: "EH1 1YZ" },
  { weightGrams: 400, lengthCm: 60, widthCm: 40, heightCm: 40, destinationPostcode: "HS1 2AA" },
  { weightGrams: 31_000, lengthCm: 50, widthCm: 50, heightCm: 50, destinationPostcode: "M1 1AE" },
];

for (const parcel of parcels) {
  console.log(`To ${parcel.destinationPostcode}:`);
  for (const quote of quoteAllServices(parcel)) {
    console.log(`  ${formatQuote(quote)}`);
  }
}
TS
