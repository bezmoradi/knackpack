#!/bin/bash
# A contacts service with an HTTP API and a command that imports partners'
# CSV files. The uncommitted change validates contacts in the handler and in
# Store.Add; the import, which the change doesn't touch, calls Store.Add
# directly.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p contacts cmd/import cmd/server
cat > go.mod <<'GO'
module example.com/contacts

go 1.22
GO
cat > contacts/contacts.go <<'GO'
// Package contacts keeps the address book.
package contacts

import "fmt"

// Contact is one address book entry.
type Contact struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

// ParseRow turns one CSV row of name and email into a Contact.
func ParseRow(fields []string) (Contact, error) {
	if len(fields) != 2 {
		return Contact{}, fmt.Errorf("want 2 fields, got %d", len(fields))
	}
	return Contact{Name: fields[0], Email: fields[1]}, nil
}
GO
cat > contacts/store.go <<'GO'
package contacts

import (
	"encoding/json"
	"os"
	"sync"
)

// Store appends contacts to a JSON Lines file.
type Store struct {
	mu   sync.Mutex
	Path string
}

// Add appends c to the file.
func (s *Store) Add(c Contact) error {
	line, err := json.Marshal(c)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	f, err := os.OpenFile(s.Path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	if _, err := f.Write(append(line, '\n')); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}
GO
cat > contacts/handler.go <<'GO'
package contacts

import (
	"encoding/json"
	"log"
	"net/http"
)

// Handler serves POST /contacts.
type Handler struct {
	Store *Store
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var c Contact
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&c); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if err := h.Store.Add(c); err != nil {
		log.Printf("add contact: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}
GO
cat > cmd/server/main.go <<'GO'
// Command server serves the contacts API.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/contacts/contacts"
)

func main() {
	store := &contacts.Store{Path: "contacts.jsonl"}
	mux := http.NewServeMux()
	mux.Handle("POST /contacts", contacts.Handler{Store: store})
	srv := &http.Server{Addr: ":8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > cmd/import/main.go <<'GO'
// Command import adds the contacts in partners' CSV files (name,email per
// row) to the address book: import <file>...
package main

import (
	"encoding/csv"
	"errors"
	"io"
	"log"
	"os"

	"example.com/contacts/contacts"
)

func main() {
	store := &contacts.Store{Path: "contacts.jsonl"}
	for _, name := range os.Args[1:] {
		if err := importFile(store, name); err != nil {
			log.Fatalf("%s: %v", name, err)
		}
	}
}

func importFile(store *contacts.Store, name string) error {
	f, err := os.Open(name)
	if err != nil {
		return err
	}
	defer f.Close()
	r := csv.NewReader(f)
	for row := 1; ; row++ {
		fields, err := r.Read()
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		c, err := contacts.ParseRow(fields)
		if err == nil {
			err = store.Add(c)
		}
		if err != nil {
			log.Printf("%s row %d skipped: %v", name, row, err)
		}
	}
}
GO
git add -A
git commit -qm "Contacts API and partner CSV import"
cat > contacts/contacts.go <<'GO'
// Package contacts keeps the address book.
package contacts

import (
	"errors"
	"fmt"
	"net/mail"
	"strings"
	"unicode/utf8"
)

// Contact is one address book entry.
type Contact struct {
	Name  string `json:"name"`
	Email string `json:"email"`
}

// ErrInvalid means a contact can't be stored as it is.
var ErrInvalid = errors.New("invalid contact")

// Validate reports whether c can be stored: a name of 1 to 100 characters
// and one email address.
func Validate(c Contact) error {
	if n := utf8.RuneCountInString(strings.TrimSpace(c.Name)); n == 0 || n > 100 {
		return fmt.Errorf("%w: the name must be 1 to 100 characters", ErrInvalid)
	}
	if a, err := mail.ParseAddress(c.Email); err != nil || a.Address != c.Email {
		return fmt.Errorf("%w: %q isn't an email address", ErrInvalid, c.Email)
	}
	return nil
}

// ParseRow turns one CSV row of name and email into a Contact.
func ParseRow(fields []string) (Contact, error) {
	if len(fields) != 2 {
		return Contact{}, fmt.Errorf("want 2 fields, got %d", len(fields))
	}
	return Contact{Name: fields[0], Email: fields[1]}, nil
}
GO
cat > contacts/store.go <<'GO'
package contacts

import (
	"encoding/json"
	"os"
	"sync"
)

// Store appends contacts to a JSON Lines file.
type Store struct {
	mu   sync.Mutex
	Path string
}

// Add validates c and appends it to the file.
func (s *Store) Add(c Contact) error {
	if err := Validate(c); err != nil {
		return err
	}
	line, err := json.Marshal(c)
	if err != nil {
		return err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	f, err := os.OpenFile(s.Path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	if _, err := f.Write(append(line, '\n')); err != nil {
		f.Close()
		return err
	}
	return f.Close()
}
GO
cat > contacts/handler.go <<'GO'
package contacts

import (
	"encoding/json"
	"log"
	"net/http"
)

// Handler serves POST /contacts.
type Handler struct {
	Store *Store
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var c Contact
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<16)).Decode(&c); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	if err := Validate(c); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if err := h.Store.Add(c); err != nil {
		log.Printf("add contact: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
}
GO
