#!/bin/bash
# A recipe community's profile API, plus an uncommitted endpoint that copies
# chosen fields into a patch, so fields the client didn't send become undefined.
set -euo pipefail
git init -q -b main
git config user.name "Lucia Romano"
git config user.email "lucia.romano@example.com"
mkdir -p src/profiles src/routes docs

cat > package.json <<'JSON'
{
  "name": "panfolk-api",
  "version": "3.4.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "start": "node dist/server.js"
  },
  "devDependencies": {
    "@types/node": "^22.12.0",
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
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/profiles/types.ts <<'TS'
export interface Profile {
  id: string;
  displayName: string;
  bio: string;
  website: string;
  favouriteCuisine: string;
}

// A partial update. A field that is absent from the patch is left unchanged.
export type ProfilePatch = Partial<Omit<Profile, "id">>;
TS

cat > src/profiles/store.ts <<'TS'
import type { Profile, ProfilePatch } from "./types.js";

const profiles = new Map<string, Profile>();

export function putProfile(profile: Profile): void {
  profiles.set(profile.id, profile);
}

export function getProfile(id: string): Profile | undefined {
  return profiles.get(id);
}

export function updateProfile(id: string, patch: ProfilePatch): Profile {
  const current = profiles.get(id);
  if (!current) throw new Error(`no profile ${id}`);
  const updated: Profile = { ...current, ...patch, id };
  profiles.set(id, updated);
  return updated;
}
TS

cat > src/routes/getProfile.ts <<'TS'
import { getProfile } from "../profiles/store.js";

export function handleGetProfile(id: string): { status: number; body: unknown } {
  const profile = getProfile(id);
  return profile ? { status: 200, body: profile } : { status: 404, body: { error: "not found" } };
}
TS

cat > docs/api.md <<'MD'
# Profile API

`GET /profiles/:id` returns the profile.

`PATCH /profiles/:id` updates the fields in the request body and leaves the
others as they are. The app's settings screens each send only their own
fields: the name screen sends `{"displayName": "..."}`, the about screen sends
`{"bio": "...", "website": "..."}`, and the tastes screen sends
`{"favouriteCuisine": "..."}`.
MD

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { handleGetProfile } from "./routes/getProfile.js";

createServer((req, res) => {
  const match = /^\/profiles\/([\w-]+)$/.exec(req.url ?? "");
  if (!match || req.method !== "GET") {
    res.writeHead(404).end();
    return;
  }
  const { status, body } = handleGetProfile(match[1]);
  res.writeHead(status, { "content-type": "application/json" }).end(JSON.stringify(body));
}).listen(Number(process.env.PORT ?? 3300));
TS

git add -A
git commit -q -m "Profile store and GET endpoint"

# Uncommitted: the PATCH endpoint.
cat > src/routes/patchProfile.ts <<'TS'
import { getProfile, updateProfile } from "../profiles/store.js";
import type { ProfilePatch } from "../profiles/types.js";

export interface PatchBody {
  displayName?: string;
  bio?: string;
  website?: string;
  favouriteCuisine?: string;
}

const EDITABLE = ["displayName", "bio", "website", "favouriteCuisine"] as const;

export function isPatchBody(value: unknown): value is PatchBody {
  if (typeof value !== "object" || value === null) return false;
  const record = value as Record<string, unknown>;
  return EDITABLE.every((key) => record[key] === undefined || typeof record[key] === "string");
}

export function handlePatchProfile(id: string, body: PatchBody): { status: number; body: unknown } {
  if (!getProfile(id)) {
    return { status: 404, body: { error: "not found" } };
  }
  if (body.displayName !== undefined && body.displayName.trim() === "") {
    return { status: 400, body: { error: "displayName can't be blank" } };
  }
  // Copy only the editable fields, so a client can't overwrite id or
  // anything else we add to Profile later.
  const patch: ProfilePatch = {
    displayName: body.displayName?.trim(),
    bio: body.bio,
    website: body.website,
    favouriteCuisine: body.favouriteCuisine,
  };
  return { status: 200, body: updateProfile(id, patch) };
}
TS

cat > src/server.ts <<'TS'
import { createServer } from "node:http";
import { handleGetProfile } from "./routes/getProfile.js";
import { handlePatchProfile, isPatchBody } from "./routes/patchProfile.js";

createServer((req, res) => {
  const match = /^\/profiles\/([\w-]+)$/.exec(req.url ?? "");
  if (!match || (req.method !== "GET" && req.method !== "PATCH")) {
    res.writeHead(404).end();
    return;
  }
  const id = match[1];
  if (req.method === "GET") {
    const { status, body } = handleGetProfile(id);
    res.writeHead(status, { "content-type": "application/json" }).end(JSON.stringify(body));
    return;
  }
  let raw = "";
  req.on("data", (chunk) => (raw += chunk));
  req.on("end", () => {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      res.writeHead(400).end("invalid JSON");
      return;
    }
    if (!isPatchBody(parsed)) {
      res.writeHead(400).end("expected an object of string fields");
      return;
    }
    const { status, body } = handlePatchProfile(id, parsed);
    res.writeHead(status, { "content-type": "application/json" }).end(JSON.stringify(body));
  });
}).listen(Number(process.env.PORT ?? 3300));
TS
