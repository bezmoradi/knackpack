#!/bin/bash
# A tiny health-check service with all its code in package main at the module
# root, which is a valid Go layout, plus an uncommitted, correct GET /version
# endpoint.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
cat > go.mod <<'GO'
module example.com/healthz

go 1.22
GO
cat > main.go <<'GO'
// Command healthz answers the load balancer's liveness checks.
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
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	shutdownDone := make(chan struct{})
	go func() {
		defer close(shutdownDone)
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("shutdown: %v", err)
		}
	}()

	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
	<-shutdownDone
}

func routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthz)
	return mux
}

func healthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}
GO
cat > README.md <<'MD'
# healthz

Answers `GET /healthz` with 204 for the load balancer. Build with
`go build -ldflags "-X main.version=1.2.3"` to set the reported version.
MD
git add -A
git commit -qm "Add the health-check service"
cat > version.go <<'GO'
package main

import (
	"encoding/json"
	"log"
	"net/http"
)

// version is set at build time with -ldflags "-X main.version=...".
var version = "dev"

type versionResponse struct {
	Version string `json:"version"`
}

func versionHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(versionResponse{Version: version}); err != nil {
		log.Printf("version: %v", err)
	}
}
GO
cat > main.go <<'GO'
// Command healthz answers the load balancer's liveness checks.
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
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	shutdownDone := make(chan struct{})
	go func() {
		defer close(shutdownDone)
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("shutdown: %v", err)
		}
	}()

	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
	<-shutdownDone
}

func routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", healthz)
	mux.HandleFunc("GET /version", versionHandler)
	return mux
}

func healthz(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}
GO
cat > README.md <<'MD'
# healthz

Answers `GET /healthz` with 204 for the load balancer, and `GET /version`
with `{"version": "..."}`. Build with `go build -ldflags "-X main.version=1.2.3"`
to set the reported version.
MD
