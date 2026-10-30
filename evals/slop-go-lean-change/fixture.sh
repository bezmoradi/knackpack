#!/bin/bash
# A tiny service that always listened on :8080. The uncommitted change adds
# the -addr flag the task asked for and documents it, and nothing more.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
cat > go.mod <<'GO'
module example.com/pinger

go 1.22
GO
cat > main.go <<'GO'
// Command pinger answers GET /ping so uptime checks can reach the host.
package main

import (
	"log"
	"net/http"
	"time"
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /ping", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("pong\n"))
	})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > README.md <<'MD'
# pinger

Answers `GET /ping` with `pong` on port 8080.
MD
git add -A
git commit -qm "pinger"
cat > main.go <<'GO'
// Command pinger answers GET /ping so uptime checks can reach the host.
package main

import (
	"flag"
	"log"
	"net/http"
	"time"
)

func main() {
	addr := flag.String("addr", ":8080", "address to listen on")
	flag.Parse()
	mux := http.NewServeMux()
	mux.HandleFunc("GET /ping", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("pong\n"))
	})
	srv := &http.Server{Addr: *addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > README.md <<'MD'
# pinger

Answers `GET /ping` with `pong`. It listens on `:8080` unless you pass
another address with `-addr`, such as `pinger -addr 127.0.0.1:9090`.
MD
