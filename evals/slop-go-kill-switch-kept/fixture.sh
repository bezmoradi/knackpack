#!/bin/bash
# An internal exports service. The uncommitted change adds the CSV export of
# orders that finance asked for, with a switch on-call can use to turn it off
# without a deploy. Nothing in the code sets the switch, but an incident
# review in the repository requires one for every bulk export.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p orders export cmd/exports docs/incidents
cat > go.mod <<'GO'
module example.com/exports

go 1.22
GO
cat > orders/orders.go <<'GO'
// Package orders reads placed orders from the reporting API.
package orders

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// Order is one placed order.
type Order struct {
	ID         string    `json:"id"`
	CustomerID string    `json:"customer_id"`
	TotalCents int64     `json:"total_cents"`
	PlacedAt   time.Time `json:"placed_at"`
}

// Store lists the orders placed in a time range.
type Store interface {
	List(ctx context.Context, from, to time.Time) ([]Order, error)
}

// APIStore lists orders through the reporting API.
type APIStore struct {
	BaseURL string
	Client  *http.Client
}

// List returns the orders placed in [from, to).
func (s APIStore) List(ctx context.Context, from, to time.Time) ([]Order, error) {
	q := url.Values{"from": {from.Format(time.RFC3339)}, "to": {to.Format(time.RFC3339)}}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.BaseURL+"/orders?"+q.Encode(), nil)
	if err != nil {
		return nil, err
	}
	resp, err := s.Client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("list orders: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("list orders: the reporting API answered %s", resp.Status)
	}
	var out []Order
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode orders: %w", err)
	}
	return out, nil
}
GO
cat > cmd/exports/main.go <<'GO'
// Command exports serves the internal export endpoints.
package main

import (
	"log"
	"net/http"
	"time"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > docs/runbook.md <<'MD'
# Exports runbook

## Restart the service

`kubectl -n exports rollout restart deploy/exports`

## Turn off a bulk export

Each bulk export has an environment variable that turns it off. Set it to
`true` on the `exports` deployment and restart; the export answers 503 until
you unset it.
MD
cat > docs/incidents/2026-09-14-reporting-db-overload.md <<'MD'
# 2026-09-14: Reporting database overloaded by a bulk export

## What happened

A partner's script called the shipments bulk export in a loop. Each call
scanned a month of shipments on the reporting replica, the replica fell
behind, and dashboards showed stale data for two hours. On-call had no way
to turn the export off without a deploy, which took 40 minutes to approve.

## Action items

1. Every new bulk export ships with a switch on-call can flip without a
   deploy. An environment variable read at startup is enough. List it under
   "Turn off a bulk export" in docs/runbook.md. Owner: platform team.
2. Bulk exports cap the date range they accept. Owner: platform team.
MD
git add -A
git commit -qm "Exports service skeleton, runbook and incident review"
cat > export/csv.go <<'GO'
// Package export serves bulk exports for internal teams.
package export

import (
	"encoding/csv"
	"log"
	"net/http"
	"strconv"
	"time"

	"example.com/exports/orders"
)

// maxRange is the longest date range one export may cover.
const maxRange = 31 * 24 * time.Hour

// OrdersCSV serves GET /exports/orders.csv?from=YYYY-MM-DD&to=YYYY-MM-DD.
type OrdersCSV struct {
	Store orders.Store
	// Disabled turns the export off.
	Disabled bool
}

func (h OrdersCSV) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	if h.Disabled {
		w.Header().Set("Retry-After", "3600")
		http.Error(w, "the orders export is turned off", http.StatusServiceUnavailable)
		return
	}
	from, err1 := time.Parse(time.DateOnly, r.URL.Query().Get("from"))
	to, err2 := time.Parse(time.DateOnly, r.URL.Query().Get("to"))
	if err1 != nil || err2 != nil || !from.Before(to) || to.Sub(from) > maxRange {
		http.Error(w, "from and to must be dates (YYYY-MM-DD), from before to, at most 31 days apart", http.StatusBadRequest)
		return
	}
	list, err := h.Store.List(r.Context(), from, to)
	if err != nil {
		log.Printf("orders export: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="orders.csv"`)
	cw := csv.NewWriter(w)
	_ = cw.Write([]string{"id", "customer_id", "total_cents", "placed_at"})
	for _, o := range list {
		_ = cw.Write([]string{o.ID, o.CustomerID, strconv.FormatInt(o.TotalCents, 10), o.PlacedAt.UTC().Format(time.RFC3339)})
	}
	cw.Flush()
	if err := cw.Error(); err != nil {
		log.Printf("orders export: write: %v", err)
	}
}
GO
cat > cmd/exports/main.go <<'GO'
// Command exports serves the internal export endpoints.
package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"example.com/exports/export"
	"example.com/exports/orders"
)

func main() {
	store := orders.APIStore{
		BaseURL: os.Getenv("REPORTING_API_URL"),
		Client:  &http.Client{Timeout: 30 * time.Second},
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
	mux.Handle("GET /exports/orders.csv", export.OrdersCSV{
		Store:    store,
		Disabled: os.Getenv("ORDERS_EXPORT_DISABLED") == "true",
	})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > docs/runbook.md <<'MD'
# Exports runbook

## Restart the service

`kubectl -n exports rollout restart deploy/exports`

## Turn off a bulk export

Each bulk export has an environment variable that turns it off. Set it to
`true` on the `exports` deployment and restart; the export answers 503 until
you unset it.

- Orders CSV (`GET /exports/orders.csv`): `ORDERS_EXPORT_DISABLED`
MD
