#!/bin/bash
# A TypeScript project with a recursive utility type; the user only asks what
# it does, which changes nothing.
set -euo pipefail
git init -q -b main
git config user.name "Tomas Lindqvist"
git config user.email "tomas@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "studio-settings",
  "version": "1.4.0",
  "private": true,
  "devDependencies": { "typescript": "5.9.3" }
}
JSON
cat > tsconfig.json <<'JSON'
{ "compilerOptions": { "target": "es2022", "module": "esnext", "moduleResolution": "bundler", "strict": true, "noEmit": true }, "include": ["src"] }
JSON
cat > src/types.ts <<'TS'
export type DeepReadonly<T> =
  T extends (...args: never[]) => unknown
    ? T
    : T extends readonly (infer U)[]
      ? ReadonlyArray<DeepReadonly<U>>
      : T extends object
        ? { readonly [K in keyof T]: DeepReadonly<T[K]> }
        : T;
TS
cat > src/settings.ts <<'TS'
import type { DeepReadonly } from "./types";

export interface StudioSettings {
  theme: { accent: string; density: "compact" | "comfortable" };
  shortcuts: { key: string; action: string }[];
  onSave: (next: StudioSettings) => void;
}

export function freezeSettings(s: StudioSettings): DeepReadonly<StudioSettings> {
  return s;
}
TS
git add -A
git commit -q -m "Readonly settings view"
