#!/bin/bash
# A shop service that served orders from an in-memory map. The uncommitted
# change loads them from the ledger service through a small adapter that
# translates the ledger's 404 into the error the handler maps to a 404.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p internal/ledger orders cmd/shop
cat > go.mod <<'GO'
module example.com/shop

go 1.22
GO
cat > internal/ledger/client.go <<'GO'
// Package ledger is a client for the ledger service's HTTP API.
package ledger

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"
)

// Entry is one ledger entry.
type Entry struct {
	ID          string `json:"id"`
	Account     string `json:"account"`
	AmountCents int64  `json:"amount_cents"`
}

// APIError is a response from the ledger with a status other than 200.
type APIError struct {
	Status int
	Body   string
}

func (e *APIError) Error() string {
	return fmt.Sprintf("ledger answered %d: %s", e.Status, e.Body)
}

// Client calls the ledger service.
type Client struct {
	baseURL string
	http    *http.Client
}

// New returns a Client for the ledger at baseURL.
func New(baseURL string) *Client {
	return &Client{baseURL: baseURL, http: &http.Client{Timeout: 10 * time.Second}}
}

// GetEntry returns the entry with the given ID. A missing entry is an
// *APIError with Status 404.
func (c *Client) GetEntry(ctx context.Context, id string) (Entry, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/entries/"+url.PathEscape(id), nil)
	if err != nil {
		return Entry{}, err
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return Entry{}, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 512))
		return Entry{}, &APIError{Status: resp.StatusCode, Body: string(body)}
	}
	var e Entry
	if err := json.NewDecoder(resp.Body).Decode(&e); err != nil {
		return Entry{}, fmt.Errorf("decode entry: %w", err)
	}
	return e, nil
}
GO
cat > orders/orders.go <<'GO'
// Package orders serves orders.
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

// Source loads orders.
type Source interface {
	Order(ctx context.Context, id string) (Order, error)
}
GO
cat > orders/memsource.go <<'GO'
package orders

import "context"

// MemSource serves orders from a map. The prototype used it, and the tests
// still do.
type MemSource map[string]Order

// Order returns the order with the given ID, or ErrNotFound.
func (m MemSource) Order(ctx context.Context, id string) (Order, error) {
	o, ok := m[id]
	if !ok {
		return Order{}, ErrNotFound
	}
	return o, nil
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

// Handler serves GET /orders/{id}.
type Handler struct {
	Source Source
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	o, err := h.Source.Order(r.Context(), r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	if err != nil {
		log.Printf("load order: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(o); err != nil {
		log.Printf("encode order: %v", err)
	}
}
GO
cat > orders/handler_test.go <<'GO'
package orders

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandlerAnswersNotFound(t *testing.T) {
	mux := http.NewServeMux()
	mux.Handle("GET /orders/{id}", Handler{Source: MemSource{"1": {ID: "1", CustomerID: "c1", TotalCents: 1200}}})
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/orders/2", nil))
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status = %d, want 404", rec.Code)
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

	"example.com/shop/orders"
)

func main() {
	src := orders.MemSource{"1": {ID: "1", CustomerID: "c1", TotalCents: 1200}}
	mux := http.NewServeMux()
	mux.Handle("GET /orders/{id}", orders.Handler{Source: src})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "Order endpoint on an in-memory prototype source"
cat > orders/ledger.go <<'GO'
package orders

import (
	"context"
	"errors"
	"fmt"
	"net/http"

	"example.com/shop/internal/ledger"
)

// LedgerSource loads orders from the ledger service.
type LedgerSource struct {
	Client *ledger.Client
}

// Order returns the order with the given ID, or ErrNotFound when the ledger
// has no such entry.
func (s LedgerSource) Order(ctx context.Context, id string) (Order, error) {
	e, err := s.Client.GetEntry(ctx, id)
	var apiErr *ledger.APIError
	if errors.As(err, &apiErr) && apiErr.Status == http.StatusNotFound {
		return Order{}, ErrNotFound
	}
	if err != nil {
		return Order{}, fmt.Errorf("load order %s from the ledger: %w", id, err)
	}
	return Order{ID: e.ID, CustomerID: e.Account, TotalCents: e.AmountCents}, nil
}
GO
cat > cmd/shop/main.go <<'GO'
// Command shop serves the shop's API.
package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"example.com/shop/internal/ledger"
	"example.com/shop/orders"
)

func main() {
	src := orders.LedgerSource{Client: ledger.New(os.Getenv("LEDGER_URL"))}
	mux := http.NewServeMux()
	mux.Handle("GET /orders/{id}", orders.Handler{Source: src})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
