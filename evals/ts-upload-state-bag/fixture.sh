#!/bin/bash
# A property listing editor with a photo gallery, plus an uncommitted upload
# model whose type lets an upload be "done" without a url.
set -euo pipefail
git init -q -b main
git config user.name "Marisol Vega"
git config user.email "marisol.vega@example.com"
mkdir -p src/gallery src/uploads

cat > package.json <<'JSON'
{
  "name": "listing-editor",
  "version": "1.12.0",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "typecheck": "tsc -p . --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.9.3"
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

cat > src/gallery/escape.ts <<'TS'
const ENTITIES: Record<string, string> = { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" };

export function escapeHtml(text: string): string {
  return String(text).replace(/[&<>"]/g, (ch) => ENTITIES[ch]);
}
TS

cat > src/gallery/renderGallery.ts <<'TS'
import { escapeHtml } from "./escape.js";

export interface Photo {
  id: string;
  url: string;
  caption: string;
}

export function renderPhoto(photo: Photo): string {
  return `<figure><img src="${escapeHtml(photo.url)}" alt="${escapeHtml(photo.caption)}"></figure>`;
}

export function renderGallery(photos: Photo[]): string {
  return `<div class="gallery">${photos.map(renderPhoto).join("")}</div>`;
}
TS

git add -A
git commit -q -m "Listing photo gallery"

# Uncommitted: show uploads in progress, failed uploads and retries in the gallery.
cat > src/uploads/types.ts <<'TS'
export type Upload = {
  id: string;
  fileName: string;
  state: "uploading" | "done" | "failed";
  progress: number;
  url?: string;
  error?: string;
};

export interface PhotoFile {
  name: string;
  hash: string;
  bytes: Uint8Array;
}

// Sends the file to storage and resolves with its public URL.
export type PutFile = (file: PhotoFile, onProgress: (percent: number) => void) => Promise<string>;
TS

cat > src/uploads/uploader.ts <<'TS'
import type { PhotoFile, PutFile, Upload } from "./types.js";

// Files already stored during this editing session, by content hash, so a
// retry doesn't send the same bytes twice.
const storedHashes = new Map<string, { storedAt: number }>();

export async function startUpload(id: string, file: PhotoFile, put: PutFile): Promise<Upload> {
  let upload: Upload = { id, fileName: file.name, state: "uploading", progress: 0 };
  try {
    const url = await put(file, (percent) => {
      upload = { ...upload, progress: percent };
    });
    storedHashes.set(file.hash, { storedAt: Date.now() });
    return { ...upload, state: "done", progress: 100, url };
  } catch (err) {
    return { ...upload, state: "failed", error: err instanceof Error ? err.message : String(err) };
  }
}

export async function retryUpload(upload: Upload, file: PhotoFile, put: PutFile): Promise<Upload> {
  if (storedHashes.has(file.hash)) {
    return { ...upload, state: "done", progress: 100, error: undefined };
  }
  return startUpload(upload.id, file, put);
}
TS

cat > src/gallery/renderUpload.ts <<'TS'
import type { Upload } from "../uploads/types.js";
import { escapeHtml } from "./escape.js";

export function renderUpload(upload: Upload): string {
  if (upload.state === "done") {
    return `<figure><img src="${escapeHtml(upload.url!)}" alt="${escapeHtml(upload.fileName)}"></figure>`;
  }
  if (upload.state === "failed") {
    return `<figure class="failed">${escapeHtml(upload.fileName)}: ${escapeHtml(upload.error ?? "upload failed")} <button data-retry="${upload.id}">Retry</button></figure>`;
  }
  return `<figure class="uploading"><progress max="100" value="${upload.progress}"></progress></figure>`;
}
TS
