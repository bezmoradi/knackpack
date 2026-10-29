#!/bin/bash
# A TypeScript module with an abstract class, three one-method subclasses and
# a static factory, all to compute one of three shipping rates.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "shipping-quotes",
  "private": true,
  "type": "module",
  "scripts": { "typecheck": "tsc --noEmit" },
  "devDependencies": { "typescript": "^5.4.0" }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src"]
}
JSON
cat > src/shipping.ts <<'TS'
export type ShippingKind = "standard" | "express" | "overnight";

export abstract class Shipping {
  abstract rate(weightKg: number): number;
}

export class StandardShipping extends Shipping {
  rate(weightKg: number): number {
    return 4.99 + 0.5 * weightKg;
  }
}

export class ExpressShipping extends Shipping {
  rate(weightKg: number): number {
    return 9.99 + 1.2 * weightKg;
  }
}

export class OvernightShipping extends Shipping {
  rate(weightKg: number): number {
    return 19.99 + 2.5 * weightKg;
  }
}

export class ShippingFactory {
  static create(kind: ShippingKind): Shipping {
    switch (kind) {
      case "standard":
        return new StandardShipping();
      case "express":
        return new ExpressShipping();
      case "overnight":
        return new OvernightShipping();
    }
  }
}
TS
cat > src/quote.ts <<'TS'
import { ShippingFactory, type ShippingKind } from "./shipping.js";

export function quote(kind: ShippingKind, weightKg: number): number {
  const shipping = ShippingFactory.create(kind);
  return Math.round(shipping.rate(weightKg) * 100) / 100;
}
TS
git add -A
git commit -qm "Shipping rates through a class hierarchy"
