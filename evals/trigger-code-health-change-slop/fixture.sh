#!/bin/bash
# A small Go timesheet service with three months of history, and an
# uncommitted change that adds a CSV export: an Exporter interface with one
# implementation, an options struct whose one field nothing sets, and the
# handler that uses them. The question is about that one change.
set -euo pipefail
git init -q -b main
git config user.name "Owen Clarke"
git config user.email "owen@example.com"
now=$(date +%s)

commit() { # <days ago> <message>
	local ts=$((now - $1 * 86400))
	git add -A
	GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$2"
}

cat > go.mod <<'GO'
module example.com/timesheets

go 1.22
GO
cat > entries.go <<'GO'
package main

import (
	"sort"
	"sync"
	"time"
)

// Entry is time someone spent on a project.
type Entry struct {
	Person  string    `json:"person"`
	Project string    `json:"project"`
	Day     time.Time `json:"day"`
	Minutes int       `json:"minutes"`
}

// Store keeps entries in memory.
type Store struct {
	mu      sync.Mutex
	entries []Entry
}

// Add records an entry.
func (s *Store) Add(e Entry) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.entries = append(s.entries, e)
}

// Month returns the entries in the month that contains day, oldest first.
func (s *Store) Month(day time.Time) []Entry {
	s.mu.Lock()
	defer s.mu.Unlock()
	var out []Entry
	for _, e := range s.entries {
		if e.Day.Year() == day.Year() && e.Day.Month() == day.Month() {
			out = append(out, e)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Day.Before(out[j].Day) })
	return out
}
GO
cat > main.go <<'GO'
// Command timesheets records time spent on projects.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

func main() {
	store := &Store{}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /entries", func(w http.ResponseWriter, r *http.Request) {
		var e Entry
		if err := json.NewDecoder(r.Body).Decode(&e); err != nil || e.Person == "" || e.Project == "" || e.Minutes <= 0 {
			http.Error(w, "need person, project, day and positive minutes", http.StatusBadRequest)
			return
		}
		store.Add(e)
		w.WriteHeader(http.StatusCreated)
	})
	mux.HandleFunc("GET /entries/{month}", func(w http.ResponseWriter, r *http.Request) {
		month, err := time.Parse("2006-01", r.PathValue("month"))
		if err != nil {
			http.Error(w, "month must look like 2026-03", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(store.Month(month))
	})
	srv := &http.Server{Addr: "127.0.0.1:8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
cat > README.md <<'MD'
# timesheets

    POST /entries          {"person", "project", "day", "minutes"}
    GET  /entries/2026-03  the month's entries as JSON
MD
commit 95 "Record and list timesheet entries"

cat > entries_test.go <<'GO'
package main

import (
	"testing"
	"time"
)

func TestMonthKeepsOnlyThatMonthInOrder(t *testing.T) {
	s := &Store{}
	s.Add(Entry{Person: "ana", Project: "web", Day: time.Date(2026, 3, 9, 0, 0, 0, 0, time.UTC), Minutes: 60})
	s.Add(Entry{Person: "ana", Project: "web", Day: time.Date(2026, 4, 1, 0, 0, 0, 0, time.UTC), Minutes: 30})
	s.Add(Entry{Person: "ben", Project: "app", Day: time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC), Minutes: 90})
	got := s.Month(time.Date(2026, 3, 15, 0, 0, 0, 0, time.UTC))
	if len(got) != 2 || got[0].Person != "ben" {
		t.Fatalf("got %+v", got)
	}
}
GO
commit 61 "Test the month filter"

sed -i.bak 's/^    GET  \/entries\/2026-03  the month.s entries as JSON$/    GET  \/entries\/2026-03  the month'"'"'s entries as JSON, oldest first/' README.md
rm README.md.bak
commit 30 "README: entries come oldest first"

cat > export.go <<'GO'
package main

import (
	"encoding/csv"
	"io"
	"strconv"
)

// Exporter writes entries in some file format.
type Exporter interface {
	Export(w io.Writer, entries []Entry) error
}

// ExportOptions configures an export.
type ExportOptions struct {
	Delimiter rune
}

type csvExporter struct {
	opts ExportOptions
}

// NewCSVExporter returns an Exporter that writes CSV.
func NewCSVExporter(opts ExportOptions) Exporter {
	if opts.Delimiter == 0 {
		opts.Delimiter = ','
	}
	return &csvExporter{opts: opts}
}

func (c *csvExporter) Export(w io.Writer, entries []Entry) error {
	cw := csv.NewWriter(w)
	cw.Comma = c.opts.Delimiter
	if err := cw.Write([]string{"person", "project", "day", "minutes"}); err != nil {
		return err
	}
	for _, e := range entries {
		if err := cw.Write([]string{e.Person, e.Project, e.Day.Format("2006-01-02"), strconv.Itoa(e.Minutes)}); err != nil {
			return err
		}
	}
	cw.Flush()
	return cw.Error()
}
GO
cat > main.go <<'GO'
// Command timesheets records time spent on projects.
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"time"
)

func main() {
	store := &Store{}
	exporter := NewCSVExporter(ExportOptions{})
	mux := http.NewServeMux()
	mux.HandleFunc("POST /entries", func(w http.ResponseWriter, r *http.Request) {
		var e Entry
		if err := json.NewDecoder(r.Body).Decode(&e); err != nil || e.Person == "" || e.Project == "" || e.Minutes <= 0 {
			http.Error(w, "need person, project, day and positive minutes", http.StatusBadRequest)
			return
		}
		store.Add(e)
		w.WriteHeader(http.StatusCreated)
	})
	mux.HandleFunc("GET /entries/{month}", func(w http.ResponseWriter, r *http.Request) {
		month, err := time.Parse("2006-01", r.PathValue("month"))
		if err != nil {
			http.Error(w, "month must look like 2026-03", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(store.Month(month))
	})
	mux.HandleFunc("GET /entries/{month}/csv", func(w http.ResponseWriter, r *http.Request) {
		month, err := time.Parse("2006-01", r.PathValue("month"))
		if err != nil {
			http.Error(w, "month must look like 2026-03", http.StatusBadRequest)
			return
		}
		w.Header().Set("Content-Type", "text/csv")
		w.Header().Set("Content-Disposition", `attachment; filename="timesheets-`+month.Format("2006-01")+`.csv"`)
		if err := exporter.Export(w, store.Month(month)); err != nil {
			log.Printf("export %s: %v", month.Format("2006-01"), err)
		}
	})
	srv := &http.Server{Addr: "127.0.0.1:8080", Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
GO
