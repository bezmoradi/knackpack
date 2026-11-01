#!/bin/bash
# A small Go HTTP service. The uncommitted change adds a handler that returns
# one order as JSON. The case is about which review starts, not about defects.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"

cat > go.mod <<'EOF'
module example.com/orders

go 1.22
EOF

cat > store.go <<'EOF'
package main

import "sync"

type Order struct {
	ID    string `json:"id"`
	Total int64  `json:"total_cents"`
}

type Store struct {
	mu     sync.RWMutex
	orders map[string]Order
}

func NewStore() *Store { return &Store{orders: map[string]Order{}} }

func (s *Store) Get(id string) (Order, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	o, ok := s.orders[id]
	return o, ok
}
EOF

cat > handlers.go <<'EOF'
package main

import "net/http"

func health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}
EOF

cat > main.go <<'EOF'
package main

import (
	"log"
	"net/http"
)

func main() {
	store := NewStore()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", health)
	mux.HandleFunc("GET /orders/{id}", getOrder(store))
	log.Fatal(http.ListenAndServe(":8080", mux))
}
EOF

# main.go already routes /orders/{id}; the handler arrives in the change.
cat >> handlers.go <<'EOF'

func getOrder(s *Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {}
}
EOF
git add -A
git commit -qm "orders service with a stub order handler"

cat > handlers.go <<'EOF'
package main

import (
	"encoding/json"
	"net/http"
)

func health(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

func getOrder(s *Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		o, ok := s.Get(r.PathValue("id"))
		if !ok {
			http.NotFound(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		if err := json.NewEncoder(w).Encode(o); err != nil {
			http.Error(w, "encoding failed", http.StatusInternalServerError)
		}
	}
}
EOF
