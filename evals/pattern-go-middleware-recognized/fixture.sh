#!/bin/bash
# A Go net/http server with two handlers and no middleware yet.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p server cmd/web
cat > go.mod <<'GO'
module example.com/web

go 1.22
GO
cat > server/handlers.go <<'GO'
// Package server holds the HTTP handlers.
package server

import (
	"encoding/json"
	"net/http"
	"time"
)

// Health reports that the process is up.
func Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

// Time reports the server's current time.
func Time(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"now": time.Now().UTC().Format(time.RFC3339)})
}

// Routes returns the server's mux.
func Routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", Health)
	mux.HandleFunc("GET /time", Time)
	return mux
}
GO
cat > cmd/web/main.go <<'GO'
// Command web serves the API.
package main

import (
	"log"
	"net/http"

	"example.com/web/server"
)

func main() {
	log.Fatal(http.ListenAndServe(":8080", server.Routes()))
}
GO
git add -A
git commit -qm "HTTP server with two handlers"
