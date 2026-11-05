#!/bin/bash
# A public catalog API that registers its routes on http.DefaultServeMux and
# serves it with a nil Handler, plus an uncommitted change that blank-imports
# net/http/pprof, which adds /debug/pprof to that same public mux.
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
cat > go.mod <<'GO'
module example.com/catalog

go 1.24
GO
cat > README.md <<'MD'
# catalog

The public product catalog API behind shop.example.com. It runs on port 8080
behind the internet-facing load balancer, which forwards every path to it.
MD
cat > products.go <<'GO'
package main

import (
	"encoding/json"
	"net/http"
	"sync"
)

// Product is one item in the public catalog.
type Product struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Cents int64  `json:"cents"`
}

type store struct {
	mu       sync.RWMutex
	products map[string]Product
}

func (s *store) list(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	out := make([]Product, 0, len(s.products))
	for _, p := range s.products {
		out = append(out, p)
	}
	s.mu.RUnlock()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(out)
}

func (s *store) get(w http.ResponseWriter, r *http.Request) {
	s.mu.RLock()
	p, ok := s.products[r.PathValue("id")]
	s.mu.RUnlock()
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(p)
}
GO
cat > main.go <<'GO'
// Command catalog serves the public product catalog API.
package main

import (
	"log"
	"net/http"
	"time"
)

func main() {
	s := &store{products: map[string]Product{
		"p1": {ID: "p1", Name: "Kettle", Cents: 3900},
	}}
	http.HandleFunc("GET /products", s.list)
	http.HandleFunc("GET /products/{id}", s.get)
	srv := &http.Server{
		Addr:              ":8080",
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "Serve the product catalog"
cat > main.go <<'GO'
// Command catalog serves the public product catalog API.
package main

import (
	"log"
	"net/http"
	_ "net/http/pprof" // profiles for the memory growth investigation
	"time"
)

func main() {
	s := &store{products: map[string]Product{
		"p1": {ID: "p1", Name: "Kettle", Cents: 3900},
	}}
	http.HandleFunc("GET /products", s.list)
	http.HandleFunc("GET /products/{id}", s.get)
	srv := &http.Server{
		Addr:              ":8080",
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
