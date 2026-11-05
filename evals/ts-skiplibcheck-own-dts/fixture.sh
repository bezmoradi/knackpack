#!/bin/bash
# A shop's checkout with hand-written carrier API declarations in a .d.ts, plus
# an uncommitted move to the carrier's v2 quotes that turns on skipLibCheck.
set -euo pipefail
git init -q -b main
git config user.name "Priya Raman"
git config user.email "priya.raman@example.com"
mkdir -p src/types src/shipping src/checkout docs

cat > package.json <<'JSON'
{
  "name": "fernhill-checkout",
  "version": "2.8.0",
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
    "lib": ["es2022", "dom"],
    "strict": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/money.ts <<'TS'
export type CurrencyCode = "USD" | "CAD";

export interface Money {
  amountCents: number;
  currency: CurrencyCode;
}

export function formatMoney(cents: number, currency: CurrencyCode = "USD"): string {
  return new Intl.NumberFormat("en-US", { style: "currency", currency }).format(cents / 100);
}
TS

cat > src/types/parcelway.d.ts <<'TS'
// Response shapes of the Parcelway carrier API, as we use them. These are
// global declarations, available in every file without an import.
declare namespace Parcelway {
  type Service = "ground" | "express" | "overnight";

  interface Quote {
    service: Service;
    transitDays: number;
    priceCents: number;
  }

  interface QuoteResponse {
    quotes: Quote[];
  }
}
TS

cat > src/shipping/carrierClient.ts <<'TS'
export async function fetchQuotes(postcode: string, weightGrams: number): Promise<Parcelway.QuoteResponse> {
  const res = await fetch("https://api.parcelway.example.com/v1/quotes", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ to: postcode, weight_g: weightGrams }),
  });
  if (!res.ok) throw new Error(`Parcelway quote failed: ${res.status}`);
  return (await res.json()) as Parcelway.QuoteResponse;
}
TS

cat > src/shipping/shipping.ts <<'TS'
// What the warehouse charges per parcel for packing.
export const HANDLING_FEE_CENTS = 150;

export function cheapestQuote(response: Parcelway.QuoteResponse): Parcelway.Quote | undefined {
  return [...response.quotes].sort((a, b) => a.priceCents - b.priceCents)[0];
}

export function shippingChargeCents(quote: Parcelway.Quote): number {
  return quote.priceCents + HANDLING_FEE_CENTS;
}
TS

cat > src/checkout/summary.ts <<'TS'
import { formatMoney } from "../money.js";
import { cheapestQuote, shippingChargeCents } from "../shipping/shipping.js";

export interface CartLine {
  title: string;
  priceCents: number;
  quantity: number;
}

export interface CheckoutSummary {
  itemsCents: number;
  shippingCents: number;
  totalCents: number;
  lines: string[];
}

export function checkoutSummary(cart: CartLine[], quotes: Parcelway.QuoteResponse): CheckoutSummary {
  const quote = cheapestQuote(quotes);
  if (!quote) throw new Error("no shipping options for this address");
  const itemsCents = cart.reduce((sum, line) => sum + line.priceCents * line.quantity, 0);
  const shippingCents = shippingChargeCents(quote);
  const totalCents = itemsCents + shippingCents;
  return {
    itemsCents,
    shippingCents,
    totalCents,
    lines: [
      `Items: ${formatMoney(itemsCents)}`,
      `Shipping (${quote.service}, ${quote.transitDays} days): ${formatMoney(shippingCents)}`,
      `Total: ${formatMoney(totalCents)}`,
    ],
  };
}
TS

cat > docs/parcelway-v2.md <<'MD'
# Parcelway v2 quotes

v1 is switched off on 1 December. v2 returns each price as an object with
the amount in cents and the currency, instead of a bare `price_cents`:

```json
{
  "quotes": [
    { "service": "ground", "transitDays": 4, "price": { "amountCents": 899, "currency": "USD" } },
    { "service": "express", "transitDays": 2, "price": { "amountCents": 1699, "currency": "USD" } }
  ]
}
```
MD

git add -A
git commit -q -m "Checkout summary with Parcelway shipping quotes"

# Uncommitted: move to Parcelway v2.
cat > src/types/parcelway.d.ts <<'TS'
// Response shapes of the Parcelway carrier API, as we use them. These are
// global declarations, available in every file without an import.
declare namespace Parcelway {
  type Service = "ground" | "express" | "overnight";

  interface Quote {
    service: Service;
    transitDays: number;
    price: Money;
  }

  interface QuoteResponse {
    quotes: Quote[];
  }
}
TS

cat > src/shipping/carrierClient.ts <<'TS'
export async function fetchQuotes(postcode: string, weightGrams: number): Promise<Parcelway.QuoteResponse> {
  const res = await fetch("https://api.parcelway.example.com/v2/quotes", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ to: postcode, weight_g: weightGrams }),
  });
  if (!res.ok) throw new Error(`Parcelway quote failed: ${res.status}`);
  return (await res.json()) as Parcelway.QuoteResponse;
}
TS

cat > src/shipping/shipping.ts <<'TS'
// What the warehouse charges per parcel for packing.
export const HANDLING_FEE_CENTS = 150;

export function cheapestQuote(response: Parcelway.QuoteResponse): Parcelway.Quote | undefined {
  return [...response.quotes].sort((a, b) => a.price.amountCents - b.price.amountCents)[0];
}

export function shippingChargeCents(quote: Parcelway.Quote): number {
  return quote.price.cents + HANDLING_FEE_CENTS;
}
TS

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "lib": ["es2022", "dom"],
    "strict": true,
    "skipLibCheck": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON
