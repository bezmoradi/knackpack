#!/bin/bash
# A shop service whose customer endpoints call their store directly. The
# uncommitted change adds order endpoints through an orders.Service whose
# every method only passes the call to the store.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p customers orders cmd/shop
cat > go.mod <<'GO'
module example.com/shop

go 1.22
GO
cat > customers/customers.go <<'GO'
// Package customers stores and serves customer records.
package customers

import (
	"context"
	"errors"
)

// Customer is one shop customer.
type Customer struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
}

// ErrNotFound means no customer has the requested ID.
var ErrNotFound = errors.New("customer not found")

// Store keeps customers.
type Store interface {
	Get(ctx context.Context, id string) (Customer, error)
	List(ctx context.Context) ([]Customer, error)
}
GO
cat > customers/memstore.go <<'GO'
package customers

import (
	"context"
	"sort"
	"sync"
)

// MemStore is a Store kept in memory.
type MemStore struct {
	mu   sync.Mutex
	byID map[string]Customer
}

// NewMemStore returns a MemStore holding cs.
func NewMemStore(cs ...Customer) *MemStore {
	m := &MemStore{byID: make(map[string]Customer, len(cs))}
	for _, c := range cs {
		m.byID[c.ID] = c
	}
	return m
}

// Get returns the customer with the given ID, or ErrNotFound.
func (m *MemStore) Get(ctx context.Context, id string) (Customer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	c, ok := m.byID[id]
	if !ok {
		return Customer{}, ErrNotFound
	}
	return c, nil
}

// List returns every customer, ordered by ID.
func (m *MemStore) List(ctx context.Context) ([]Customer, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	out := make([]Customer, 0, len(m.byID))
	for _, c := range m.byID {
		out = append(out, c)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}
GO
cat > customers/handler.go <<'GO'
package customers

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
)

// Handler serves the customer endpoints from its store.
type Handler struct {
	Store Store
}

// Get serves GET /customers/{id}.
func (h Handler) Get(w http.ResponseWriter, r *http.Request) {
	c, err := h.Store.Get(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("get customer: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, c)
}

// List serves GET /customers.
func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	cs, err := h.Store.List(r.Context())
	if err != nil {
		log.Printf("list customers: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, cs)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("encode response: %v", err)
	}
}
GO
cat > cmd/shop/main.go <<'GO'
// Command shop serves the shop's API.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/shop/customers"
)

func main() {
	ch := customers.Handler{Store: customers.NewMemStore()}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /customers", ch.List)
	mux.HandleFunc("GET /customers/{id}", ch.Get)
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "Customer endpoints"
cat > orders/orders.go <<'GO'
// Package orders stores and serves orders.
package orders

import (
	"context"
	"errors"
)

// Order is one placed order.
type Order struct {
	ID         string `json:"id"`
	CustomerID string `json:"customer_id"`
	TotalCents int64  `json:"total_cents"`
}

// ErrNotFound means no order has the requested ID.
var ErrNotFound = errors.New("order not found")

// Store keeps orders.
type Store interface {
	Get(ctx context.Context, id string) (Order, error)
	ListByCustomer(ctx context.Context, customerID string) ([]Order, error)
	Create(ctx context.Context, o Order) (Order, error)
}
GO
cat > orders/memstore.go <<'GO'
package orders

import (
	"context"
	"strconv"
	"sync"
)

// MemStore is a Store kept in memory.
type MemStore struct {
	mu   sync.Mutex
	byID map[string]Order
	next int
}

// NewMemStore returns an empty MemStore.
func NewMemStore() *MemStore {
	return &MemStore{byID: make(map[string]Order)}
}

// Get returns the order with the given ID, or ErrNotFound.
func (m *MemStore) Get(ctx context.Context, id string) (Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	o, ok := m.byID[id]
	if !ok {
		return Order{}, ErrNotFound
	}
	return o, nil
}

// ListByCustomer returns the customer's orders, oldest first.
func (m *MemStore) ListByCustomer(ctx context.Context, customerID string) ([]Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var out []Order
	for i := 1; i <= m.next; i++ {
		if o, ok := m.byID[strconv.Itoa(i)]; ok && o.CustomerID == customerID {
			out = append(out, o)
		}
	}
	return out, nil
}

// Create stores o under a new ID and returns it.
func (m *MemStore) Create(ctx context.Context, o Order) (Order, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.next++
	o.ID = strconv.Itoa(m.next)
	m.byID[o.ID] = o
	return o, nil
}
GO
cat > orders/service.go <<'GO'
package orders

import "context"

// Service holds the order business logic.
type Service struct {
	store Store
}

// NewService returns a Service backed by store.
func NewService(store Store) *Service {
	return &Service{store: store}
}

// GetOrder returns the order with the given ID.
func (s *Service) GetOrder(ctx context.Context, id string) (Order, error) {
	return s.store.Get(ctx, id)
}

// ListOrders returns a customer's orders.
func (s *Service) ListOrders(ctx context.Context, customerID string) ([]Order, error) {
	return s.store.ListByCustomer(ctx, customerID)
}

// CreateOrder stores a new order.
func (s *Service) CreateOrder(ctx context.Context, o Order) (Order, error) {
	return s.store.Create(ctx, o)
}
GO
cat > orders/handler.go <<'GO'
package orders

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
)

// Handler serves the order endpoints.
type Handler struct {
	Service *Service
}

// Get serves GET /orders/{id}.
func (h Handler) Get(w http.ResponseWriter, r *http.Request) {
	o, err := h.Service.GetOrder(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("get order: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, o)
}

// List serves GET /customers/{id}/orders.
func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	list, err := h.Service.ListOrders(r.Context(), r.PathValue("id"))
	if err != nil {
		log.Printf("list orders: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, list)
}

// Create serves POST /orders.
func (h Handler) Create(w http.ResponseWriter, r *http.Request) {
	var o Order
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20)).Decode(&o); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if o.CustomerID == "" || o.TotalCents <= 0 {
		http.Error(w, "customer_id is required and total_cents must be positive", http.StatusBadRequest)
		return
	}
	o, err := h.Service.CreateOrder(r.Context(), o)
	if err != nil {
		log.Printf("create order: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusCreated, o)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("encode response: %v", err)
	}
}
GO
cat > cmd/shop/main.go <<'GO'
// Command shop serves the shop's API.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/shop/customers"
	"example.com/shop/orders"
)

func main() {
	ch := customers.Handler{Store: customers.NewMemStore()}
	oh := orders.Handler{Service: orders.NewService(orders.NewMemStore())}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /customers", ch.List)
	mux.HandleFunc("GET /customers/{id}", ch.Get)
	mux.HandleFunc("GET /customers/{id}/orders", oh.List)
	mux.HandleFunc("GET /orders/{id}", oh.Get)
	mux.HandleFunc("POST /orders", oh.Create)
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
