#!/bin/bash
# A checkout service whose handler takes seconds to finish, plus an uncommitted
# change that adds graceful shutdown on SIGTERM correctly, with a fresh timeout
# for Shutdown.
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
mkdir -p cmd/checkout internal/checkout
cat > go.mod <<'GO'
module example.com/checkout

go 1.24
GO
cat > internal/checkout/handler.go <<'GO'
// Package checkout charges a cart and records the order.
package checkout

import (
	"encoding/json"
	"net/http"
	"time"
)

// Payments charges a customer's card.
type Payments interface {
	Charge(r *http.Request, cartID string, cents int64) (string, error)
}

// Handler serves POST /checkout.
type Handler struct {
	Payments Payments
}

type request struct {
	CartID string `json:"cart_id"`
	Cents  int64  `json:"cents"`
}

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var req request
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	// The provider usually answers in two to five seconds.
	id, err := h.Payments.Charge(r, req.CartID, req.Cents)
	if err != nil {
		http.Error(w, "payment failed", http.StatusBadGateway)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"charge_id": id, "at": time.Now().UTC().Format(time.RFC3339)})
}
GO
cat > cmd/checkout/main.go <<'GO'
// Command checkout serves the checkout API.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/checkout/internal/checkout"
)

type fakePayments struct{}

func (fakePayments) Charge(r *http.Request, cartID string, cents int64) (string, error) {
	time.Sleep(3 * time.Second)
	return "ch_" + cartID, nil
}

func main() {
	mux := http.NewServeMux()
	mux.Handle("POST /checkout", &checkout.Handler{Payments: fakePayments{}})
	srv := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "Add the checkout service"
cat > cmd/checkout/main.go <<'GO'
// Command checkout serves the checkout API.
package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"example.com/checkout/internal/checkout"
)

type fakePayments struct{}

func (fakePayments) Charge(r *http.Request, cartID string, cents int64) (string, error) {
	time.Sleep(3 * time.Second)
	return "ch_" + cartID, nil
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	mux := http.NewServeMux()
	mux.Handle("POST /checkout", &checkout.Handler{Payments: fakePayments{}})
	srv := &http.Server{
		Addr:              ":8080",
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
	}()

	select {
	case err := <-serveErr:
		log.Fatalf("server: %v", err)
	case <-ctx.Done():
	}

	// Stop taking new requests and let the ones in flight finish, within
	// Kubernetes' default 30-second termination grace period.
	log.Print("shutting down")
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("shutdown: %v", err)
	}
	log.Print("stopped")
}
GO
