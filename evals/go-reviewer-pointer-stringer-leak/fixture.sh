#!/bin/bash
# A gateway whose config holds an upstream API key, plus an uncommitted change
# that adds a redacting String method on the pointer receiver and logs the
# config value at startup, which prints every field.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p config cmd/gateway
cat > go.mod <<'GO'
module example.com/gateway

go 1.22
GO
cat > config/config.go <<'GO'
// Package config loads the gateway's settings from the environment.
package config

import (
	"errors"
	"os"
)

// Config holds the gateway's settings. APIKey authenticates calls to the
// upstream payments provider and must never be logged.
type Config struct {
	ListenAddr  string
	UpstreamURL string
	APIKey      string
}

// Load reads the settings from the environment.
func Load() (Config, error) {
	c := Config{
		ListenAddr:  os.Getenv("LISTEN_ADDR"),
		UpstreamURL: os.Getenv("UPSTREAM_URL"),
		APIKey:      os.Getenv("UPSTREAM_API_KEY"),
	}
	if c.APIKey == "" {
		return Config{}, errors.New("config: UPSTREAM_API_KEY is required")
	}
	if c.ListenAddr == "" {
		c.ListenAddr = ":8080"
	}
	return c, nil
}
GO
cat > cmd/gateway/main.go <<'GO'
// Command gateway serves the payments gateway.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/gateway/config"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("listening on %s", cfg.ListenAddr)
	srv := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           http.NotFoundHandler(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
git add -A
git commit -qm "Add the gateway and its config"
cat > config/config.go <<'GO'
// Package config loads the gateway's settings from the environment.
package config

import (
	"errors"
	"fmt"
	"os"
)

// Config holds the gateway's settings. APIKey authenticates calls to the
// upstream payments provider and must never be logged.
type Config struct {
	ListenAddr  string
	UpstreamURL string
	APIKey      string
}

// Load reads the settings from the environment.
func Load() (Config, error) {
	c := Config{
		ListenAddr:  os.Getenv("LISTEN_ADDR"),
		UpstreamURL: os.Getenv("UPSTREAM_URL"),
		APIKey:      os.Getenv("UPSTREAM_API_KEY"),
	}
	if c.APIKey == "" {
		return Config{}, errors.New("config: UPSTREAM_API_KEY is required")
	}
	if c.ListenAddr == "" {
		c.ListenAddr = ":8080"
	}
	return c, nil
}

// String describes c for logs, with the API key redacted.
func (c *Config) String() string {
	return fmt.Sprintf("Config{ListenAddr: %s, UpstreamURL: %s, APIKey: [redacted]}", c.ListenAddr, c.UpstreamURL)
}
GO
cat > cmd/gateway/main.go <<'GO'
// Command gateway serves the payments gateway.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/gateway/config"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatal(err)
	}
	log.Printf("starting with %v", cfg)
	srv := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           http.NotFoundHandler(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Fatal(srv.ListenAndServe())
}
GO
