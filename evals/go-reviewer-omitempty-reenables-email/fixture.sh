#!/bin/bash
# A preferences service with a browser client that treats a missing
# email_enabled as true and saves the whole object back, plus an uncommitted
# change that adds omitempty to every field of the response.
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
mkdir -p web
cat > go.mod <<'GO'
module example.com/prefs

go 1.24
GO
cat > prefs.go <<'GO'
// Command prefs serves each user's notification preferences.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"
)

// Prefs are one user's notification settings.
type Prefs struct {
	EmailEnabled bool     `json:"email_enabled"`
	SMSEnabled   bool     `json:"sms_enabled"`
	QuietHours   string   `json:"quiet_hours"`
	Topics       []string `json:"topics"`
}

type store struct {
	mu    sync.Mutex
	prefs map[string]Prefs
}

func (s *store) get(w http.ResponseWriter, r *http.Request) {
	s.mu.Lock()
	p := s.prefs[r.PathValue("user")]
	s.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(p)
}

func (s *store) put(w http.ResponseWriter, r *http.Request) {
	var p Prefs
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<14))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&p); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	s.mu.Lock()
	s.prefs[r.PathValue("user")] = p
	s.mu.Unlock()
	w.WriteHeader(http.StatusNoContent)
}

func main() {
	s := &store{prefs: map[string]Prefs{}}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /users/{user}/prefs", s.get)
	mux.HandleFunc("PUT /users/{user}/prefs", s.put)
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > web/prefs.js <<'JS'
// Settings page: loads the user's notification preferences and saves them.
// Accounts created before email_enabled existed don't have the field; email
// was on for them, so a missing value means on.

export async function loadPrefs(user) {
  const res = await fetch(`/users/${user}/prefs`);
  const p = await res.json();
  return {
    email_enabled: p.email_enabled ?? true,
    sms_enabled: p.sms_enabled ?? false,
    quiet_hours: p.quiet_hours ?? "",
    topics: p.topics ?? [],
  };
}

// savePrefs sends the whole form back, since PUT replaces the stored prefs.
export async function savePrefs(user, prefs) {
  await fetch(`/users/${user}/prefs`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(prefs),
  });
}
JS
git add -A
git commit -qm "Serve notification preferences"
sed -i.bak -E 's/`json:"(email_enabled|sms_enabled|quiet_hours|topics)"`/`json:"\1,omitempty"`/' prefs.go
rm prefs.go.bak
