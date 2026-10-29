#!/bin/bash
# A repository with a Go service tracking job progress and a TypeScript browser
# client that polls it. Neither side has a notification mechanism yet.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p jobs cmd/jobsd web/src
cat > go.mod <<'GO'
module example.com/progress

go 1.22
GO
cat > jobs/tracker.go <<'GO'
// Package jobs tracks the progress of long-running jobs.
package jobs

import (
	"context"
	"errors"
	"sync"
)

// ErrUnknownJob is returned for an ID that was never started.
var ErrUnknownJob = errors.New("jobs: unknown job")

// Progress is a job's state at one moment.
type Progress struct {
	ID      string
	Percent int
	Done    bool
}

// Tracker records progress reported by workers. Workers call Report from
// their own goroutines; the HTTP layer reads with Get.
type Tracker struct {
	mu   sync.RWMutex
	jobs map[string]Progress
}

// New returns an empty Tracker.
func New() *Tracker { return &Tracker{jobs: map[string]Progress{}} }

// Report records p for p.ID.
func (t *Tracker) Report(ctx context.Context, p Progress) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	t.mu.Lock()
	defer t.mu.Unlock()
	t.jobs[p.ID] = p
	return nil
}

// Get returns the last reported progress for id.
func (t *Tracker) Get(id string) (Progress, error) {
	t.mu.RLock()
	defer t.mu.RUnlock()
	p, ok := t.jobs[id]
	if !ok {
		return Progress{}, ErrUnknownJob
	}
	return p, nil
}
GO
cat > cmd/jobsd/main.go <<'GO'
// Command jobsd serves job progress over HTTP.
package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"

	"example.com/progress/jobs"
)

func main() {
	tracker := jobs.New()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /jobs/{id}", func(w http.ResponseWriter, r *http.Request) {
		p, err := tracker.Get(r.PathValue("id"))
		if errors.Is(err, jobs.ErrUnknownJob) {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(p)
	})
	log.Fatal(http.ListenAndServe(":8080", mux))
}
GO
cat > web/package.json <<'JSON'
{
  "name": "progress-web",
  "private": true,
  "type": "module",
  "scripts": { "typecheck": "tsc --noEmit" },
  "devDependencies": { "typescript": "^5.4.0" }
}
JSON
cat > web/tsconfig.json <<'JSON'
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
cat > web/src/progress.ts <<'TS'
// Polls one job's progress and hands each reading to a renderer.

export interface Progress {
  id: string;
  percent: number;
  done: boolean;
}

export async function fetchProgress(id: string, signal?: AbortSignal): Promise<Progress> {
  const res = await fetch(`/jobs/${encodeURIComponent(id)}`, { signal });
  if (!res.ok) {
    throw new Error(`job ${id}: ${res.status}`);
  }
  return (await res.json()) as Progress;
}

export async function pollProgress(
  id: string,
  render: (p: Progress) => void,
  intervalMs = 1000,
  signal?: AbortSignal,
): Promise<void> {
  while (!signal?.aborted) {
    const p = await fetchProgress(id, signal);
    render(p);
    if (p.done) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
}
TS
cat > web/src/widgets.ts <<'TS'
import type { Progress } from "./progress.js";

export function renderBar(el: HTMLElement): (p: Progress) => void {
  return (p) => {
    el.style.width = `${p.percent}%`;
    el.textContent = p.done ? "done" : `${p.percent}%`;
  };
}

export function renderLog(el: HTMLElement): (p: Progress) => void {
  return (p) => {
    const line = document.createElement("div");
    line.textContent = `${p.id}: ${p.percent}%`;
    el.append(line);
  };
}
TS
git add -A
git commit -qm "Job progress service and polling client"
