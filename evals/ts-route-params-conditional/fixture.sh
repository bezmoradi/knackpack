#!/bin/bash
# A small router package shared by a storefront's pages, plus an uncommitted
# change that infers route params with nested conditional and template-literal types.
set -euo pipefail
git init -q -b main
git config user.name "Felix Brandt"
git config user.email "felix.brandt@example.com"
mkdir -p src docs

cat > package.json <<'JSON'
{
  "name": "@harbourline/router",
  "version": "1.3.0",
  "description": "Path matching and links for Harbourline storefront pages.",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "default": "./dist/index.js"
    }
  },
  "files": ["dist"],
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
    "strict": true,
    "declaration": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/match.ts <<'TS'
export interface CompiledPattern {
  names: string[];
  regex: RegExp;
}

function escapeRegExp(text: string): string {
  return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

// Patterns are slash-separated segments. ":name" is a required parameter and
// ":name?" an optional one; anything else matches literally.
export function compilePattern(pattern: string): CompiledPattern {
  const names: string[] = [];
  let source = "";
  for (const segment of pattern.split("/").filter(Boolean)) {
    if (segment.startsWith(":")) {
      const optional = segment.endsWith("?");
      names.push(segment.slice(1, optional ? -1 : undefined));
      source += optional ? "(?:/([^/]+))?" : "/([^/]+)";
    } else {
      source += `/${escapeRegExp(segment)}`;
    }
  }
  return { names, regex: new RegExp(`^${source || "/"}/?$`) };
}

export function matchPath(pattern: string, path: string): Record<string, string | undefined> | null {
  const { names, regex } = compilePattern(pattern);
  const found = regex.exec(path);
  if (!found) return null;
  const params: Record<string, string | undefined> = {};
  names.forEach((name, i) => {
    const value = found[i + 1];
    params[name] = value === undefined ? undefined : decodeURIComponent(value);
  });
  return params;
}
TS

cat > src/href.ts <<'TS'
export function href(pattern: string, params: Record<string, string | undefined> = {}): string {
  const parts: string[] = [];
  for (const segment of pattern.split("/").filter(Boolean)) {
    if (!segment.startsWith(":")) {
      parts.push(segment);
      continue;
    }
    const optional = segment.endsWith("?");
    const name = segment.slice(1, optional ? -1 : undefined);
    const value = params[name];
    if (value === undefined) {
      if (optional) continue;
      throw new Error(`href: missing parameter "${name}" for ${pattern}`);
    }
    parts.push(encodeURIComponent(value));
  }
  return `/${parts.join("/")}`;
}
TS

cat > src/index.ts <<'TS'
export { href } from "./href.js";
export { compilePattern, matchPath } from "./match.js";
TS

cat > README.md <<'MD'
# @harbourline/router

Path matching and links for the storefront's pages.

```ts
import { href, matchPath } from "@harbourline/router";

href("/stores/:storeId/orders/:orderId", { storeId: "s1", orderId: "o9" }); // "/stores/s1/orders/o9"
matchPath("/stores/:storeId/orders/:orderId/:tab?", "/stores/s1/orders/o9");
// { storeId: "s1", orderId: "o9", tab: undefined }
```
MD

git add -A
git commit -q -m "Router 1.3.0: optional parameters"

# Uncommitted: typed routes, released as 1.4.0.
cat > src/params.ts <<'TS'
// Type-level version of compilePattern in match.ts: keep the two in step.

type Split<Path extends string> = Path extends `${infer Head}/${infer Rest}`
  ? [Head, ...Split<Rest>]
  : [Path];

type ParamFromSegment<Segment extends string> = Segment extends `:${infer Name}?`
  ? { [K in Name]?: string }
  : Segment extends `:${infer Name}`
    ? { [K in Name]: string }
    : {};

type UnionToIntersection<U> = (U extends unknown ? (arg: U) => void : never) extends (arg: infer I) => void
  ? I
  : never;

type Merge<T> = { [K in keyof T]: T[K] };

export type ExtractParams<Pattern extends string> = string extends Pattern
  ? Record<string, string | undefined>
  : Merge<UnionToIntersection<ParamFromSegment<Split<Pattern>[number]>>>;

export type HrefArgs<Pattern extends string> = keyof ExtractParams<Pattern> extends never
  ? []
  : {} extends ExtractParams<Pattern>
    ? [params?: ExtractParams<Pattern>]
    : [params: ExtractParams<Pattern>];
TS

cat > src/route.ts <<'TS'
import { matchPath } from "./match.js";
import type { ExtractParams } from "./params.js";

export interface Route<Pattern extends string> {
  readonly name: string;
  readonly pattern: Pattern;
}

export function defineRoute<const Pattern extends string>(name: string, pattern: Pattern): Route<Pattern> {
  return { name, pattern };
}

export function matchRoute<Pattern extends string>(
  route: Route<Pattern>,
  path: string,
): ExtractParams<Pattern> | null {
  return matchPath(route.pattern, path) as ExtractParams<Pattern> | null;
}
TS

cat > src/href.ts <<'TS'
import type { HrefArgs } from "./params.js";
import type { Route } from "./route.js";

export function href<Pattern extends string>(route: Route<Pattern>, ...args: NoInfer<HrefArgs<Pattern>>): string;
export function href<Pattern extends string>(pattern: Pattern, ...args: NoInfer<HrefArgs<Pattern>>): string;
export function href(
  routeOrPattern: Route<string> | string,
  params: Record<string, string | undefined> = {},
): string {
  const pattern = typeof routeOrPattern === "string" ? routeOrPattern : routeOrPattern.pattern;
  const parts: string[] = [];
  for (const segment of pattern.split("/").filter(Boolean)) {
    if (!segment.startsWith(":")) {
      parts.push(segment);
      continue;
    }
    const optional = segment.endsWith("?");
    const name = segment.slice(1, optional ? -1 : undefined);
    const value = params[name];
    if (value === undefined) {
      if (optional) continue;
      throw new Error(`href: missing parameter "${name}" for ${pattern}`);
    }
    parts.push(encodeURIComponent(value));
  }
  return `/${parts.join("/")}`;
}
TS

cat > src/index.ts <<'TS'
export { href } from "./href.js";
export { compilePattern, matchPath } from "./match.js";
export type { ExtractParams, HrefArgs } from "./params.js";
export { defineRoute, matchRoute, type Route } from "./route.js";
TS

cat > README.md <<'MD'
# @harbourline/router

Path matching and links for the storefront's pages.

```ts
import { defineRoute, href, matchRoute } from "@harbourline/router";

export const orderPage = defineRoute("order", "/stores/:storeId/orders/:orderId/:tab?");

href(orderPage, { storeId: "s1", orderId: "o9" }); // "/stores/s1/orders/o9"
matchRoute(orderPage, "/stores/s1/orders/o9/returns");
// { storeId: "s1", orderId: "o9", tab: "returns" }, typed as
// { storeId: string; orderId: string; tab?: string }
```

Parameter names are checked at compile time: a missing or misspelled
parameter is a type error. See [docs/troubleshooting.md](docs/troubleshooting.md)
if the error is hard to read.
MD

cat > docs/troubleshooting.md <<'MD'
# Troubleshooting typed routes

## A misspelled parameter

This call in the storefront spells `orderId` as `orderID`:

```ts
href(orderPage, { storeId, orderID: orderId, tab: "returns" });
```

and tsc reports:

```text
app/pages/orderLinks.ts(6,10): error TS2769: No overload matches this call.
  Argument of type '[{ storeId: string; orderID: string; tab: string; }]' is not assignable to parameter of type '[params: Merge<{ storeId: string; } & { orderId: string; } & { tab?: string | undefined; }>]'.
    Object literal may only specify known properties, but 'orderID' does not exist in type 'Merge<{ storeId: string; } & { orderId: string; } & { tab?: string | undefined; }>'. Did you mean to write 'orderId'?
  Overload 2 of 2, '(pattern: string, ...args: NoInfer<[params?: Record<string, string | undefined> | undefined]>): string', gave the following error.
    Argument of type 'Route<"/stores/:storeId/orders/:orderId/:tab?">' is not assignable to parameter of type 'string'.
```

Ignore the second overload; the "Did you mean" line names the parameter.

## Calling href from a generic helper

A helper that is generic over the route doesn't compile:

```ts
export function navLink<P extends string>(label: string, route: Route<P>, params: ExtractParams<P>): string {
  return `<a href="${href(route, params)}">${label}</a>`;
}
```

```text
app/pages/navLink.ts(4,22): error TS2769: No overload matches this call.
  Argument of type '[ExtractParams<P>]' is not assignable to parameter of type 'HrefArgs<P>'.
  Overload 2 of 2, '(pattern: string, ...args: NoInfer<[params?: Record<string, string | undefined> | undefined]>): string', gave the following error.
    Argument of type 'Route<P>' is not assignable to parameter of type 'string'.
```

TypeScript can't resolve `HrefArgs<P>` while `P` is still generic. Spread
the params as the expected tuple: `href(route, ...([params] as HrefArgs<P>))`.
MD

cat > package.json <<'JSON'
{
  "name": "@harbourline/router",
  "version": "1.4.0",
  "description": "Path matching and links for Harbourline storefront pages.",
  "type": "module",
  "exports": {
    ".": {
      "types": "./dist/index.d.ts",
      "default": "./dist/index.js"
    }
  },
  "files": ["dist"],
  "scripts": {
    "build": "tsc -p ."
  },
  "devDependencies": {
    "typescript": "^5.8.3"
  }
}
JSON
