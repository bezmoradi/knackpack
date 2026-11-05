#!/bin/bash
# A pricing service whose plan cache is guarded by a sync.RWMutex and refreshed
# every minute, plus an uncommitted summary method that takes the read lock and
# then calls Len, which takes it again.
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
mkdir -p internal/plans cmd/pricing
cat > go.mod <<'GO'
module example.com/pricing

go 1.24
GO
cat > internal/plans/cache.go <<'GO'
// Package plans caches the rate plans that pricing requests read.
package plans

import (
	"context"
	"sort"
	"sync"
)

// Plan is one rate plan.
type Plan struct {
	ID          string
	Name        string
	CentsPerDay int64
}

// Loader fetches every plan from the plans database.
type Loader func(ctx context.Context) ([]Plan, error)

// Cache holds the plans in memory. Pricing requests read it concurrently;
// Refresh replaces its contents every minute.
type Cache struct {
	mu    sync.RWMutex
	plans map[string]Plan
	load  Loader
}

// NewCache returns an empty cache that loads plans with load.
func NewCache(load Loader) *Cache {
	return &Cache{plans: map[string]Plan{}, load: load}
}

// Get returns the plan with the given ID.
func (c *Cache) Get(id string) (Plan, bool) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	p, ok := c.plans[id]
	return p, ok
}

// Len returns the number of cached plans.
func (c *Cache) Len() int {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return len(c.plans)
}

// Refresh reloads every plan and swaps them in.
func (c *Cache) Refresh(ctx context.Context) error {
	ps, err := c.load(ctx)
	if err != nil {
		return err
	}
	next := make(map[string]Plan, len(ps))
	for _, p := range ps {
		next[p.ID] = p
	}
	c.mu.Lock()
	c.plans = next
	c.mu.Unlock()
	return nil
}

// IDs returns the cached plan IDs in order.
func (c *Cache) IDs() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	ids := make([]string, 0, len(c.plans))
	for id := range c.plans {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}
GO
cat > internal/plans/cache_test.go <<'GO'
package plans

import (
	"context"
	"testing"
)

func TestRefreshAndGet(t *testing.T) {
	c := NewCache(func(context.Context) ([]Plan, error) {
		return []Plan{{ID: "basic", Name: "Basic", CentsPerDay: 100}}, nil
	})
	if err := c.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	if p, ok := c.Get("basic"); !ok || p.CentsPerDay != 100 {
		t.Fatalf("Get(basic) = %v, %v", p, ok)
	}
	if c.Len() != 1 {
		t.Fatalf("Len() = %d, want 1", c.Len())
	}
}
GO
cat > cmd/pricing/main.go <<'GO'
// Command pricing serves price quotes from the cached rate plans.
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"example.com/pricing/internal/plans"
)

func loadPlans(ctx context.Context) ([]plans.Plan, error) {
	return []plans.Plan{{ID: "basic", Name: "Basic", CentsPerDay: 100}}, nil
}

func main() {
	cache := plans.NewCache(loadPlans)
	if err := cache.Refresh(context.Background()); err != nil {
		log.Fatal(err)
	}
	go func() {
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for range t.C {
			if err := cache.Refresh(context.Background()); err != nil {
				log.Printf("refresh plans: %v", err)
			}
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /quote/{plan}", func(w http.ResponseWriter, r *http.Request) {
		p, ok := cache.Get(r.PathValue("plan"))
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]int64{"cents_per_day": p.CentsPerDay})
	})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "Cache rate plans and serve quotes"
cat >> internal/plans/cache.go <<'GO'

// Summary describes the cached plans for the support page.
type Summary struct {
	Count int      `json:"count"`
	Names []string `json:"names"`
}

// Summary returns the number of cached plans and their names, sorted.
func (c *Cache) Summary() Summary {
	c.mu.RLock()
	defer c.mu.RUnlock()
	names := make([]string, 0, len(c.plans))
	for _, p := range c.plans {
		names = append(names, p.Name)
	}
	sort.Strings(names)
	return Summary{Count: c.Len(), Names: names}
}
GO
cat >> internal/plans/cache_test.go <<'GO'

func TestSummary(t *testing.T) {
	c := NewCache(func(context.Context) ([]Plan, error) {
		return []Plan{{ID: "pro", Name: "Pro"}, {ID: "basic", Name: "Basic"}}, nil
	})
	if err := c.Refresh(context.Background()); err != nil {
		t.Fatal(err)
	}
	s := c.Summary()
	if s.Count != 2 || len(s.Names) != 2 || s.Names[0] != "Basic" {
		t.Fatalf("Summary() = %+v", s)
	}
}
GO
cat > cmd/pricing/main.go <<'GO'
// Command pricing serves price quotes from the cached rate plans.
package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"example.com/pricing/internal/plans"
)

func loadPlans(ctx context.Context) ([]plans.Plan, error) {
	return []plans.Plan{{ID: "basic", Name: "Basic", CentsPerDay: 100}}, nil
}

func main() {
	cache := plans.NewCache(loadPlans)
	if err := cache.Refresh(context.Background()); err != nil {
		log.Fatal(err)
	}
	go func() {
		t := time.NewTicker(time.Minute)
		defer t.Stop()
		for range t.C {
			if err := cache.Refresh(context.Background()); err != nil {
				log.Printf("refresh plans: %v", err)
			}
		}
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /quote/{plan}", func(w http.ResponseWriter, r *http.Request) {
		p, ok := cache.Get(r.PathValue("plan"))
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]int64{"cents_per_day": p.CentsPerDay})
	})
	mux.HandleFunc("GET /plans/summary", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(cache.Summary())
	})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
