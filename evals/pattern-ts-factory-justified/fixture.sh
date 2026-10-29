#!/bin/bash
# A TypeScript library where the parser for a response is chosen at run time
# from its content type, parsers are registered by plug-in modules, and a
# test constructs one parser directly.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p src/parsers src/plugins
cat > package.json <<'JSON'
{
  "name": "feedreader",
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
    "lib": ["ES2022", "DOM"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src"]
}
JSON
cat > src/parsers/parser.ts <<'TS'
export interface Item {
  title: string;
  url: string;
}

export interface Parser {
  parse(body: string): Item[];
}
TS
cat > src/parsers/json.ts <<'TS'
import type { Item, Parser } from "./parser.js";

export class JsonParser implements Parser {
  parse(body: string): Item[] {
    const data: unknown = JSON.parse(body);
    if (!Array.isArray(data)) {
      throw new Error("json feed: expected an array");
    }
    return data.map((raw: unknown) => {
      if (typeof raw !== "object" || raw === null) {
        throw new Error("json feed: expected objects");
      }
      const { title, url } = raw as Record<string, unknown>;
      if (typeof title !== "string" || typeof url !== "string") {
        throw new Error("json feed: item needs title and url");
      }
      return { title, url };
    });
  }
}
TS
cat > src/parsers/registry.ts <<'TS'
import type { Parser } from "./parser.js";
import { JsonParser } from "./json.js";

const factories = new Map<string, () => Parser>([["application/json", () => new JsonParser()]]);

/** Lets a plug-in add a parser for a content type it understands. */
export function registerParser(contentType: string, create: () => Parser): void {
  factories.set(contentType.toLowerCase(), create);
}

/** Picks the parser for a response's content type, ignoring parameters such as charset. */
export function createParser(contentType: string): Parser {
  const mediaType = contentType.split(";")[0]?.trim().toLowerCase() ?? "";
  const create = factories.get(mediaType);
  if (!create) {
    throw new Error(`no parser for ${mediaType || "an empty content type"}`);
  }
  return create();
}
TS
cat > src/plugins/rss.ts <<'TS'
import type { Item, Parser } from "../parsers/parser.js";
import { registerParser } from "../parsers/registry.js";

class RssParser implements Parser {
  parse(body: string): Item[] {
    const items: Item[] = [];
    for (const match of body.matchAll(/<item>[\s\S]*?<title>([\s\S]*?)<\/title>[\s\S]*?<link>([\s\S]*?)<\/link>[\s\S]*?<\/item>/g)) {
      items.push({ title: match[1]?.trim() ?? "", url: match[2]?.trim() ?? "" });
    }
    return items;
  }
}

registerParser("application/rss+xml", () => new RssParser());
TS
cat > src/fetchFeed.ts <<'TS'
import "./plugins/rss.js";
import { createParser } from "./parsers/registry.js";
import type { Item } from "./parsers/parser.js";

export async function fetchFeed(url: string, signal?: AbortSignal): Promise<Item[]> {
  const res = await fetch(url, { signal });
  if (!res.ok) {
    throw new Error(`${url}: ${res.status}`);
  }
  const parser = createParser(res.headers.get("content-type") ?? "");
  return parser.parse(await res.text());
}
TS
cat > src/parsers/json.test.ts <<'TS'
import { JsonParser } from "./json.js";

// Run with any test runner; the assertions are plain throws.
const parser = new JsonParser();
const items = parser.parse('[{"title":"One","url":"https://example.com/1"}]');
if (items.length !== 1 || items[0]?.title !== "One") {
  throw new Error("JsonParser.parse: unexpected result");
}
TS
git add -A
git commit -qm "Feed parsers chosen by content type"
