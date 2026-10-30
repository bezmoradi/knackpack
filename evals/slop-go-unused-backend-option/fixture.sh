#!/bin/bash
# A catalog service that re-reads its product file on every lookup. The
# uncommitted change adds the one-minute in-memory cache the task asked for,
# plus a "redis" backend option that nothing selects and nothing implements.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p catalog cache cmd/catalog
cat > go.mod <<'GO'
module example.com/catalog

go 1.22
GO
cat > catalog/catalog.go <<'GO'
// Package catalog serves product details.
package catalog

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
)

// Product is one item in the catalog.
type Product struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	PriceCents int64  `json:"price_cents"`
}

// ErrNotFound means no product has the requested ID.
var ErrNotFound = errors.New("product not found")

// Source loads products.
type Source interface {
	Product(ctx context.Context, id string) (Product, error)
}

// FileSource reads products from a JSON file on every lookup, so edits to
// the file show up without a restart.
type FileSource struct {
	Path string
}

// Product returns the product with the given ID, or ErrNotFound.
func (s FileSource) Product(ctx context.Context, id string) (Product, error) {
	data, err := os.ReadFile(s.Path)
	if err != nil {
		return Product{}, fmt.Errorf("read products: %w", err)
	}
	var products []Product
	if err := json.Unmarshal(data, &products); err != nil {
		return Product{}, fmt.Errorf("parse products: %w", err)
	}
	for _, p := range products {
		if p.ID == id {
			return p, nil
		}
	}
	return Product{}, ErrNotFound
}
GO
cat > catalog/handler.go <<'GO'
package catalog

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
)

// Handler serves GET /products/{id}.
type Handler struct {
	Source Source
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	p, err := h.Source.Product(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("load product: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(p); err != nil {
		log.Printf("encode product: %v", err)
	}
}
GO
cat > cmd/catalog/main.go <<'GO'
// Command catalog serves GET /products/{id}.
package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"example.com/catalog/catalog"
)

func main() {
	path := os.Getenv("PRODUCTS_FILE")
	if path == "" {
		path = "products.json"
	}
	mux := http.NewServeMux()
	mux.Handle("GET /products/{id}", catalog.Handler{Source: catalog.FileSource{Path: path}})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > README.md <<'MD'
# catalog

Serves `GET /products/{id}` from the products listed in `PRODUCTS_FILE`
(default `products.json`), a JSON array of `{id, name, price_cents}`.
MD
git add -A
git commit -qm "Serve products from the product file"
cat > cache/cache.go <<'GO'
// Package cache keeps recently loaded products in memory.
package cache

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"example.com/catalog/catalog"
)

// Options configures a product cache.
type Options struct {
	// Backend selects where cached products live: "memory" (the default)
	// or "redis".
	Backend string
	// RedisAddr is the Redis server's address when Backend is "redis".
	RedisAddr string
	// TTL is how long a product stays cached.
	TTL time.Duration
}

// Cache stores products by ID.
type Cache interface {
	Get(id string) (catalog.Product, bool)
	Set(id string, p catalog.Product)
}

// New returns the cache that opts.Backend selects.
func New(opts Options) (Cache, error) {
	switch opts.Backend {
	case "", "memory":
		return &memory{ttl: opts.TTL, items: make(map[string]entry)}, nil
	case "redis":
		return nil, errors.New("cache: the redis backend isn't implemented yet")
	default:
		return nil, fmt.Errorf("cache: unknown backend %q", opts.Backend)
	}
}

type entry struct {
	product catalog.Product
	expires time.Time
}

type memory struct {
	mu    sync.Mutex
	ttl   time.Duration
	items map[string]entry
}

func (m *memory) Get(id string) (catalog.Product, bool) {
	m.mu.Lock()
	defer m.mu.Unlock()
	e, ok := m.items[id]
	if !ok {
		return catalog.Product{}, false
	}
	if time.Now().After(e.expires) {
		delete(m.items, id)
		return catalog.Product{}, false
	}
	return e.product, true
}

func (m *memory) Set(id string, p catalog.Product) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.items[id] = entry{product: p, expires: time.Now().Add(m.ttl)}
}

// Source serves products from the cache and loads the ones it misses from
// Next.
type Source struct {
	Next  catalog.Source
	Cache Cache
}

// Product returns the cached product, or loads and caches it.
func (s Source) Product(ctx context.Context, id string) (catalog.Product, error) {
	if p, ok := s.Cache.Get(id); ok {
		return p, nil
	}
	p, err := s.Next.Product(ctx, id)
	if err != nil {
		return catalog.Product{}, err
	}
	s.Cache.Set(id, p)
	return p, nil
}
GO
cat > cmd/catalog/main.go <<'GO'
// Command catalog serves GET /products/{id}.
package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"example.com/catalog/cache"
	"example.com/catalog/catalog"
)

func main() {
	path := os.Getenv("PRODUCTS_FILE")
	if path == "" {
		path = "products.json"
	}
	c, err := cache.New(cache.Options{TTL: time.Minute})
	if err != nil {
		log.Fatal(err)
	}
	src := cache.Source{Next: catalog.FileSource{Path: path}, Cache: c}
	mux := http.NewServeMux()
	mux.Handle("GET /products/{id}", catalog.Handler{Source: src})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > README.md <<'MD'
# catalog

Serves `GET /products/{id}` from the products listed in `PRODUCTS_FILE`
(default `products.json`), a JSON array of `{id, name, price_cents}`.
Products are cached in memory for a minute, so edits to the file show up
within a minute.
MD
