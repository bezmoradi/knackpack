#!/bin/bash
# A garden supplies shop that lists its own products, plus an uncommitted import
# of a partner's product feed that casts the JSON response to Product[].
set -euo pipefail
git init -q -b main
git config user.name "Amara Okafor"
git config user.email "amara.okafor@example.com"
mkdir -p src/catalog src/partner docs

cat > package.json <<'JSON'
{
  "name": "greenhouse-shop",
  "version": "0.9.2",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "sync:partner": "node dist/partner/syncPartnerCatalog.js"
  },
  "devDependencies": {
    "@types/node": "^22.10.0",
    "typescript": "^5.9.2"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "lib": ["es2022", "dom"],
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/catalog/types.ts <<'TS'
export interface Product {
  sku: string;
  name: string;
  price: number;
  inStock: boolean;
}

export interface Listing {
  sku: string;
  title: string;
  priceLabel: string;
  available: boolean;
}
TS

cat > src/catalog/listing.ts <<'TS'
import type { Listing, Product } from "./types.js";

export function toListing(product: Product): Listing {
  return {
    sku: product.sku,
    title: product.name,
    priceLabel: `$${product.price.toFixed(2)}`,
    available: product.inStock,
  };
}
TS

cat > src/catalog/store.ts <<'TS'
import type { Listing } from "./types.js";

const listings = new Map<string, Listing>();

export function upsertListings(items: Listing[]): number {
  for (const item of items) listings.set(item.sku, item);
  return items.length;
}

export function allListings(): Listing[] {
  return [...listings.values()];
}
TS

cat > docs/partner-feed.md <<'MD'
# Partner product feed

Leafline Wholesale publishes its catalog at `GET /v2/products` as a JSON array.
Their sample response is in `partner-feed-sample.json`, copied from their
integration guide. Discontinued lines keep their entry, with `sku` set to
null, until the next quarterly cleanup, and prices are sent as decimal strings so
they never lose precision.
MD

cat > docs/partner-feed-sample.json <<'JSON'
[
  { "sku": "lf-1042", "name": "Terracotta pot, 20 cm", "price": "12.50", "inStock": true },
  { "sku": "lf-2210", "name": "Organic potting mix, 40 L", "price": "18.00", "inStock": true },
  { "sku": null, "name": "Bamboo cane bundle", "price": "4.75", "inStock": false }
]
JSON

git add -A
git commit -q -m "Catalog listings for in-house products"

# Uncommitted: import the partner's catalog.
cat > src/partner/syncPartnerCatalog.ts <<'TS'
import { upsertListings } from "../catalog/store.js";
import type { Listing, Product } from "../catalog/types.js";

const FEED_URL = process.env.PARTNER_FEED_URL ?? "https://feeds.leafline.example.com/v2/products";

export async function syncPartnerCatalog(): Promise<number> {
  const res = await fetch(FEED_URL, {
    headers: { authorization: `Bearer ${process.env.PARTNER_FEED_TOKEN ?? ""}` },
  });
  if (!res.ok) throw new Error(`partner feed returned ${res.status}`);

  const products = (await res.json()) as Product[];
  const listings: Listing[] = products.map((p) => ({
    sku: `LEAF-${p.sku.toUpperCase()}`,
    title: p.name,
    priceLabel: `$${p.price.toFixed(2)}`,
    available: p.inStock,
  }));
  return upsertListings(listings);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const count = await syncPartnerCatalog();
  console.log(`synced ${count} partner products`);
}
TS
