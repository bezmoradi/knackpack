#!/bin/bash
# A small Go command that plans an on-call rota, with seven months of history:
# three packages of under a hundred lines each, a focused test file beside
# every source file, one offline check command in the README and AGENTS.md
# that CI also runs, flags validated before use, and changes spread across the
# files. Nothing in it costs much to change.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Ines Duarte"
git config user.email "ines@example.com"
now=$(date +%s)
mkdir -p .github/workflows cmd/rota internal/calendar internal/rota

reveal() { # <step> <file>, the marked text on stdin
	awk -v k="$1" '
	match($0, / +#@[0-9]+(-[0-9]+)?$/) {
		m = substr($0, RSTART); sub(/^ +#@/, "", m); line = substr($0, 1, RSTART - 1)
		n = split(m, r, "-"); if (k + 0 >= r[1] + 0 && (n == 1 || k + 0 < r[2] + 0)) print line
		next
	}
	{ print }' > "$2"
}

put() { # <step> <first step> <text> <file>
	[ "$1" -ge "$2" ] || return 0
	printf '%s' "$3" | reveal "$1" "$4"
}

commit() { # <step> <days ago> <who> <message>
	local ts=$((now - $2 * 86400 - 3600 * ($2 % 7))) name email
	case $3 in
	ines) name="Ines Duarte" email=ines@example.com ;;
	tariq) name="Tariq Aziz" email=tariq@example.com ;;
	esac
	put "$1" 1 "$GOMOD" go.mod
	put "$1" 1 "$ROTA" internal/rota/rota.go
	put "$1" 6 "$AWAY" internal/rota/away.go
	put "$1" 1 "$ROTATEST" internal/rota/rota_test.go
	put "$1" 2 "$ICS" internal/calendar/ics.go
	put "$1" 2 "$ICSTEST" internal/calendar/ics_test.go
	put "$1" 1 "$MAIN" cmd/rota/main.go
	put "$1" 4 "$MAINTEST" cmd/rota/main_test.go
	put "$1" 5 "$CI" .github/workflows/ci.yml
	put "$1" 8 "$AGENTS" AGENTS.md
	put "$1" 1 "$README" README.md
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' GOMOD <<'GO' || true
module example.com/rota

go 1.22
GO

IFS= read -r -d '' ROTA <<'GO' || true
// Package rota gives people on-call weeks in turn.
package rota

import (
	"errors"
	"fmt"  #@9
	"time"
)

// Shift is one person's on-call week, from Start up to but not including End.
type Shift struct {
	Person string
	Start  time.Time
	End    time.Time
}

// ErrNoPeople is returned for a rota with nobody on it.
var ErrNoPeople = errors.New("rota: nobody to schedule")

// Weekly gives each person a week in turn from start, for the given number of
// weeks, passing over anyone away that week.  #@6
// weeks.  #@1-6
func Weekly(people []string, start time.Time, weeks int) ([]Shift, error) {  #@1-6
func Weekly(people []string, start time.Time, weeks int, away Away) ([]Shift, error) {  #@6
	if len(people) == 0 {
		return nil, ErrNoPeople
	}
	shifts := make([]Shift, 0, weeks)
	next := 0  #@6
	for w := 0; w < weeks; w++ {
		s := start.AddDate(0, 0, 7*w)
		e := s.AddDate(0, 0, 7)  #@6
		shifts = append(shifts, Shift{Person: people[w%len(people)], Start: s, End: s.AddDate(0, 0, 7)})  #@1-6
		p, ok := pick(people, next, func(name string) bool { return !away.During(name, s, e) })  #@6
		if !ok {  #@6
			continue  #@6-9
			return nil, fmt.Errorf("rota: everyone is away the week of %s", s.Format("2006-01-02"))  #@9
		}  #@6
		shifts = append(shifts, Shift{Person: people[p], Start: s, End: e})  #@6
		next = (p + 1) % len(people)  #@6
	}
	return shifts, nil
}
  #@6
// pick returns the first index from next on, wrapping around, whose person ok accepts.  #@6
func pick(people []string, next int, ok func(string) bool) (int, bool) {  #@6
	for i := range people {  #@6
		if p := (next + i) % len(people); ok(people[p]) {  #@6
			return p, true  #@6
		}  #@6
	}  #@6
	return 0, false  #@6
}  #@6
GO

IFS= read -r -d '' AWAY <<'GO' || true
package rota

import "time"

// Away lists each person's days off.
type Away map[string][]time.Time

// During reports whether name has a day off from from up to but not including to.
func (a Away) During(name string, from, to time.Time) bool {
	for _, d := range a[name] {
		if !d.Before(from) && d.Before(to) {
			return true
		}
	}
	return false
}
GO

IFS= read -r -d '' ROTATEST <<'GO' || true
package rota

import (
	"errors"
	"testing"
	"time"
)

var monday = time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC)

func names(shifts []Shift) []string {
	var out []string
	for _, s := range shifts {
		out = append(out, s.Person)
	}
	return out
}

func TestTakesTurns(t *testing.T) {
	got, err := Weekly([]string{"ana", "ben"}, monday, 3)  #@1-6
	got, err := Weekly([]string{"ana", "ben"}, monday, 3, nil)  #@6
	if err != nil {
		t.Fatal(err)
	}
	if n := names(got); len(n) != 3 || n[0] != "ana" || n[1] != "ben" || n[2] != "ana" {
		t.Fatalf("got %v", n)
	}
	if !got[1].Start.Equal(monday.AddDate(0, 0, 7)) {
		t.Fatalf("second week starts %v", got[1].Start)
	}
}

func TestNobody(t *testing.T) {
	if _, err := Weekly(nil, monday, 1); !errors.Is(err, ErrNoPeople) {  #@1-6
	if _, err := Weekly(nil, monday, 1, nil); !errors.Is(err, ErrNoPeople) {  #@6
		t.Fatalf("err = %v", err)
	}
}
  #@6
func TestSkipsWhoeverIsAway(t *testing.T) {  #@6
	away := Away{"ana": {monday.AddDate(0, 0, 2)}}  #@6
	got, err := Weekly([]string{"ana", "ben", "cy"}, monday, 3, away)  #@6
	if err != nil {  #@6
		t.Fatal(err)  #@6
	}  #@6
	if n := names(got); n[0] != "ben" || n[1] != "cy" || n[2] != "ana" {  #@6
		t.Fatalf("got %v", n)  #@6
	}  #@6
}  #@6
  #@9
func TestEveryoneAwayIsAnError(t *testing.T) {  #@9
	away := Away{"ana": {monday}, "ben": {monday}}  #@9
	if _, err := Weekly([]string{"ana", "ben"}, monday, 1, away); err == nil {  #@9
		t.Fatal("a week with everyone away was scheduled")  #@9
	}  #@9
}  #@9
GO

IFS= read -r -d '' ICS <<'GO' || true
// Package calendar writes rota shifts as an iCalendar file.
package calendar

import (
	"fmt"
	"io"
	"strings"
	"time"

	"example.com/rota/internal/rota"
)

// Write writes one all-day event per shift, named after the person on call.  #@2-12
// Write writes one all-day event per shift, named after the team and the person on call.  #@12
func Write(w io.Writer, shifts []rota.Shift, stamp time.Time) error {  #@2-12
func Write(w io.Writer, shifts []rota.Shift, team string, stamp time.Time) error {  #@12
	var b strings.Builder
	b.WriteString("BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//rota//EN\r\n")
	for _, s := range shifts {
		b.WriteString("BEGIN:VEVENT\r\n")
		fmt.Fprintf(&b, "UID:%s@rota\r\n", s.Start.Format("20060102"))
		fmt.Fprintf(&b, "DTSTAMP:%s\r\n", stamp.UTC().Format("20060102T150405Z"))
		fmt.Fprintf(&b, "DTSTART;VALUE=DATE:%s\r\n", s.Start.Format("20060102"))
		fmt.Fprintf(&b, "DTEND;VALUE=DATE:%s\r\n", s.Start.AddDate(0, 0, 6).Format("20060102"))  #@2-10
		fmt.Fprintf(&b, "DTEND;VALUE=DATE:%s\r\n", s.End.Format("20060102"))  #@10
		fmt.Fprintf(&b, "SUMMARY:On call: %s\r\n", s.Person)  #@2-3
		fmt.Fprintf(&b, "SUMMARY:On call: %s\r\n", escape(s.Person))  #@3-12
		fmt.Fprintf(&b, "SUMMARY:%s: %s\r\n", escape(team), escape(s.Person))  #@12
		b.WriteString("END:VEVENT\r\n")
	}
	b.WriteString("END:VCALENDAR\r\n")
	_, err := io.WriteString(w, b.String())
	return err
}
  #@3
// escape escapes text for an iCalendar TEXT value (RFC 5545, section 3.3.11).  #@3
func escape(s string) string {  #@3
	return strings.NewReplacer(`\`, `\\`, ";", `\;`, ",", `\,`, "\n", `\n`).Replace(s)  #@3
}  #@3
GO

IFS= read -r -d '' ICSTEST <<'GO' || true
package calendar

import (
	"strings"
	"testing"
	"time"

	"example.com/rota/internal/rota"
)

func TestOneEventPerShift(t *testing.T) {
	start := time.Date(2026, 3, 2, 0, 0, 0, 0, time.UTC)
	shifts := []rota.Shift{{Person: "ana", Start: start, End: start.AddDate(0, 0, 7)}, {Person: "ben", Start: start.AddDate(0, 0, 7), End: start.AddDate(0, 0, 14)}}
	var b strings.Builder
	if err := Write(&b, shifts, start); err != nil {  #@2-12
	if err := Write(&b, shifts, "on-call", start); err != nil {  #@12
		t.Fatal(err)
	}
	if n := strings.Count(b.String(), "BEGIN:VEVENT"); n != 2 {
		t.Fatalf("%d events, want 2", n)
	}
	if !strings.Contains(b.String(), "DTEND;VALUE=DATE:20260309\r\n") {  #@10
		t.Fatalf("the first event doesn't end on the next Monday:\n%s", b.String())  #@10
	}  #@10
}
  #@3
func TestEscape(t *testing.T) {  #@3
	if got := escape(`Ana; Ben, \ C`); got != `Ana\; Ben\, \\ C` {  #@3
		t.Fatalf("escape = %q", got)  #@3
	}  #@3
}  #@3
GO

IFS= read -r -d '' MAIN <<'GO' || true
// Command rota prints an on-call rota, or writes it as an iCalendar file.
package main

import (
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"time"

	"example.com/rota/internal/calendar"  #@2
	"example.com/rota/internal/rota"
)

func main() {
	if err := run(os.Args[1:], os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "rota:", err)
		os.Exit(2)
	}
}

func run(args []string, out io.Writer) error {
	fs := flag.NewFlagSet("rota", flag.ContinueOnError)
	people := fs.String("people", "", "comma-separated names, in rota order")
	start := fs.String("start", "", "the first Monday, as 2006-01-02")
	weeks := fs.Int("weeks", 8, "how many weeks to plan")
	ics := fs.Bool("ics", false, "write an iCalendar file instead of a list")  #@2
	away := fs.String("away", "", "days off, as name=2006-01-02, separated by commas")  #@7
	team := fs.String("team", "On call", "what calendar events are named after")  #@12
	if err := fs.Parse(args); err != nil {
		return err
	}
	day, err := time.Parse("2006-01-02", *start)
	if err != nil {
		return fmt.Errorf("-start: %v", err)
	}
	if day.Weekday() != time.Monday {  #@4
		return fmt.Errorf("-start %s isn't a Monday", *start)  #@4
	}  #@4
	if *weeks < 1 || *weeks > 104 {  #@4
		return fmt.Errorf("-weeks must be from 1 to 104")  #@4
	}  #@4
	off, err := parseAway(*away)  #@7
	if err != nil {  #@7
		return err  #@7
	}  #@7
	shifts, err := rota.Weekly(splitNames(*people), day, *weeks)  #@1-6
	shifts, err := rota.Weekly(splitNames(*people), day, *weeks, nil)  #@6-7
	shifts, err := rota.Weekly(splitNames(*people), day, *weeks, off)  #@7
	if err != nil {
		return err
	}
	if *ics {  #@2
		return calendar.Write(out, shifts, time.Now())  #@2-12
		return calendar.Write(out, shifts, *team, time.Now())  #@12
	}  #@2
	for _, s := range shifts {
		fmt.Fprintf(out, "%s  %s\n", s.Start.Format("2006-01-02"), s.Person)
	}
	return nil
}

func splitNames(s string) []string {
	var out []string
	for _, n := range strings.Split(s, ",") {
		if n = strings.TrimSpace(n); n != "" {
			out = append(out, n)
		}
	}
	return out
}
  #@7
func parseAway(s string) (rota.Away, error) {  #@7
	away := rota.Away{}  #@7
	for _, item := range splitNames(s) {  #@7
		name, date, ok := strings.Cut(item, "=")  #@7
		d, err := time.Parse("2006-01-02", date)  #@7
		if !ok || err != nil {  #@7
			return nil, fmt.Errorf("-away %q: want name=2006-01-02", item)  #@7
		}  #@7
		away[name] = append(away[name], d)  #@7
	}  #@7
	return away, nil  #@7
}  #@7
GO

IFS= read -r -d '' MAINTEST <<'GO' || true
package main

import (
	"strings"
	"testing"
)

func TestPrintsTheRota(t *testing.T) {
	var out strings.Builder
	if err := run([]string{"-people", "ana, ben", "-start", "2026-03-02", "-weeks", "2"}, &out); err != nil {
		t.Fatal(err)
	}
	if want := "2026-03-02  ana\n2026-03-09  ben\n"; out.String() != want {
		t.Fatalf("got %q, want %q", out.String(), want)
	}
}

func TestRejectsBadFlags(t *testing.T) {
	for _, args := range [][]string{
		{"-people", "ana", "-start", "2026-03-03"},
		{"-people", "ana", "-start", "2026-03-02", "-weeks", "0"},
		{"-people", "ana", "-start", "02/03/2026"},
		{"-people", "ana", "-start", "2026-03-02", "-away", "ana"},  #@7
	} {
		if err := run(args, &strings.Builder{}); err == nil {
			t.Errorf("run(%q) succeeded", args)
		}
	}
}
  #@7
func TestAwaySkipsAWeek(t *testing.T) {  #@7
	var out strings.Builder  #@7
	if err := run([]string{"-people", "ana,ben", "-start", "2026-03-02", "-weeks", "1", "-away", "ana=2026-03-04"}, &out); err != nil {  #@7
		t.Fatal(err)  #@7
	}  #@7
	if out.String() != "2026-03-02  ben\n" {  #@7
		t.Fatalf("got %q", out.String())  #@7
	}  #@7
}  #@7
GO

IFS= read -r -d '' CI <<'YML' || true
name: ci
on: [push, pull_request]
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          persist-credentials: false
      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod
      - run: go vet ./... && go test ./...
YML

IFS= read -r -d '' AGENTS <<'MD' || true
# Notes for coding agents

- Check every change with `go vet ./... && go test ./...`. Both run offline with
  the standard library only, and CI runs the same command.
- Each package has its tests beside it; add one for any behavior you change.
- Flags are validated in `cmd/rota`; the packages under `internal/` trust their inputs.
MD

IFS= read -r -d '' README <<'MD' || true
# rota

Plans an on-call rota: each person gets a week in turn.

    go run ./cmd/rota -people ana,ben,cy -start 2026-03-02 -weeks 6  #@11
    go run ./cmd/rota -people ana,ben,cy -start 2026-03-02 -away ben=2026-03-11 -ics > rota.ics  #@11

## Development

    go vet ./... && go test ./...
MD

commit 1 200 ines "Weekly on-call rota"
commit 2 185 ines "Write the rota as an iCalendar file"
commit 3 170 tariq "Escape names in calendar events"
commit 4 150 tariq "Validate -start and -weeks"
commit 5 132 ines "CI: vet and test"
commit 6 118 ines "Pass over people who are away"
commit 7 100 tariq "-away flag"
commit 8 84 ines "AGENTS.md: how to check a change"
commit 9 63 tariq "A week with everyone away is an error"
commit 10 45 ines "Calendar events end on the following Monday"
commit 11 27 tariq "README: examples"
commit 12 9 ines "-team names the calendar events"
