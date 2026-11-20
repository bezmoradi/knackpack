#!/bin/bash
# A Go payment-collection service with eleven months of history, and the code
# health report someone saved at the 11th commit, in .notes/ (ignored by git).
# That report has two findings: F1, nextAttempt in internal/dunning/retry.go,
# a long, nested function; and F2, (*Scheduler).Plan in
# internal/dunning/scheduler.go. The next commit split nextAttempt into one
# small function per rule; Plan hasn't changed since the 11th commit.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Grace Mwangi"
git config user.email "grace@example.com"
now=$(date +%s)
mkdir -p cmd/collector internal/accounts internal/dunning .notes/code-health

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
	grace) name="Grace Mwangi" email=grace@example.com ;;
	piotr) name="Piotr Zielinski" email=piotr@example.com ;;
	yara) name="Yara Haddad" email=yara@example.com ;;
	esac
	put "$1" 1 "$GOMOD" go.mod
	put "$1" 1 "$GITIGNORE" .gitignore
	put "$1" 1 "$ACCOUNTS" internal/accounts/accounts.go
	if [ "$1" -lt 12 ]; then put "$1" 1 "$RETRY_OLD" internal/dunning/retry.go; else put "$1" 12 "$RETRY_NEW" internal/dunning/retry.go; fi
	put "$1" 1 "$SCHEDULER" internal/dunning/scheduler.go
	put "$1" 6 "$HOLIDAYS" internal/dunning/holidays.go
	put "$1" 5 "$NOTIFY" internal/dunning/notify.go
	put "$1" 9 "$TESTS" internal/dunning/dunning_test.go
	put "$1" 1 "$MAIN" cmd/collector/main.go
	put "$1" 1 "$README" README.md
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' GOMOD <<'GO' || true
module example.com/collections

go 1.22
GO

IFS= read -r -d '' GITIGNORE <<'TXT' || true
/collector
.notes/
TXT

IFS= read -r -d '' ACCOUNTS <<'GO' || true
// Package accounts keeps customer accounts.
package accounts

import "sync"

// Account is one customer.
type Account struct {
	ID         string
	Email      string
	Enterprise bool
	Paused     bool  #@11
	Currency   string  #@15
}

// Store holds accounts in memory.
type Store struct {
	mu       sync.RWMutex
	accounts map[string]Account
}

// NewStore returns an empty store.
func NewStore() *Store {
	return &Store{accounts: make(map[string]Account)}
}

// Put adds or replaces an account.
func (s *Store) Put(a Account) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.accounts[a.ID] = a
}

// Get returns the account with the given ID.
func (s *Store) Get(id string) (Account, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	a, ok := s.accounts[id]
	return a, ok
}
GO

IFS= read -r -d '' RETRY_OLD <<'GO' || true
// Package dunning retries failed subscription payments and reminds customers.
package dunning

import "time"

// Decline is why a payment failed, as the card network reported it.
type Decline struct {
	Code    string
	Network string
	Country string
}

// Attempt is one try to collect a failed payment.
type Attempt struct {
	Number int
	At     time.Time
}

// nextAttempt decides when to retry a payment that failed with d, given the
// attempts so far, or returns false to stop retrying.
func nextAttempt(d Decline, prev []Attempt, now time.Time) (time.Time, bool) {
	n := len(prev)
	maxAttempts := 4
	if d.Country == "IN" || d.Country == "BR" {  #@8
		maxAttempts = 3  #@8
	}  #@8
	if n >= maxAttempts {
		return time.Time{}, false
	}
	var wait time.Duration
	switch d.Code {
	case "stolen_card", "lost_card", "pickup_card":  #@1-4
	case "stolen_card", "lost_card", "pickup_card", "fraudulent":  #@4
		return time.Time{}, false
	case "authentication_required":  #@10
		return time.Time{}, false  #@10
	case "insufficient_funds":
		if n == 0 {
			wait = 24 * time.Hour
		} else {
			wait = time.Duration(n) * 72 * time.Hour
			if wait > 7*24*time.Hour {
				wait = 7 * 24 * time.Hour
				if d.Network == "visa" {  #@4
					wait = 5 * 24 * time.Hour  #@4
				}  #@4
			}
		}
	case "do_not_honor", "generic_decline":  #@2
		if d.Network == "amex" {  #@2
			wait = 48 * time.Hour  #@2
		} else {  #@2
			wait = 24 * time.Hour  #@2
		}  #@2
	case "processing_error", "issuer_unavailable":  #@4
		wait = time.Hour  #@4
		if n > 1 {  #@4
			wait = 6 * time.Hour  #@4
		}  #@4
	default:
		wait = 24 * time.Hour
	}
	at := now.Add(wait)
	if n > 0 && at.Sub(prev[n-1].At) < 12*time.Hour {
		at = prev[n-1].At.Add(12 * time.Hour)
	}
	if at.Hour() < 8 {
		at = time.Date(at.Year(), at.Month(), at.Day(), 9, 0, 0, 0, at.Location())
	} else if at.Hour() >= 20 {
		at = time.Date(at.Year(), at.Month(), at.Day()+1, 9, 0, 0, 0, at.Location())
	}
	for at.Weekday() == time.Saturday || at.Weekday() == time.Sunday {  #@1-6
	for at.Weekday() == time.Saturday || at.Weekday() == time.Sunday || isHoliday(at, d.Country) {  #@6
		at = at.Add(24 * time.Hour)
	}
	return at, true
}
GO

IFS= read -r -d '' RETRY_NEW <<'GO' || true
// Package dunning retries failed subscription payments and reminds customers.
package dunning

import "time"

// Decline is why a payment failed, as the card network reported it.
type Decline struct {
	Code    string
	Network string
	Country string
}

// Attempt is one try to collect a failed payment.
type Attempt struct {
	Number int
	At     time.Time
}

// nextAttempt decides when to retry a payment that failed with d, given the
// attempts so far, or returns false to stop retrying.
func nextAttempt(d Decline, prev []Attempt, now time.Time) (time.Time, bool) {
	if len(prev) >= maxAttempts(d.Country) {
		return time.Time{}, false
	}
	wait, retry := waitFor(d, len(prev))
	if !retry {
		return time.Time{}, false
	}
	return businessDay(withinHours(spaced(now.Add(wait), prev)), d.Country), true
}

// maxAttempts is how many times we try a payment in the country.
func maxAttempts(country string) int {
	if country == "IN" || country == "BR" {
		return 3
	}
	return 4
}

// waitFor is how long to wait after the nth failure with d, or false to stop.
func waitFor(d Decline, n int) (time.Duration, bool) {
	switch d.Code {
	case "stolen_card", "lost_card", "pickup_card", "fraudulent", "authentication_required":
		return 0, false
	case "insufficient_funds":
		return fundsWait(d.Network, n), true
	case "do_not_honor", "generic_decline":
		if d.Network == "amex" {
			return 48 * time.Hour, true  #@12-13
			return 72 * time.Hour, true  #@13
		}
		return 24 * time.Hour, true
	case "processing_error", "issuer_unavailable":
		if n > 1 {
			return 6 * time.Hour, true
		}
		return time.Hour, true
	default:
		return 24 * time.Hour, true
	}
}

// fundsWait spaces retries for insufficient funds further apart each time, up to a week.
func fundsWait(network string, n int) time.Duration {
	if n == 0 {
		return 24 * time.Hour
	}
	if wait := time.Duration(n) * 72 * time.Hour; wait <= 7*24*time.Hour {
		return wait
	}
	if network == "visa" {
		return 5 * 24 * time.Hour
	}
	return 7 * 24 * time.Hour
}

// spaced keeps at least 12 hours between attempts.
func spaced(at time.Time, prev []Attempt) time.Time {
	if n := len(prev); n > 0 && at.Sub(prev[n-1].At) < 12*time.Hour {
		return prev[n-1].At.Add(12 * time.Hour)
	}
	return at
}

// withinHours moves at into 08:00 to 20:00.
func withinHours(at time.Time) time.Time {
	switch {
	case at.Hour() < 8:
		return time.Date(at.Year(), at.Month(), at.Day(), 9, 0, 0, 0, at.Location())
	case at.Hour() >= 20:
		return time.Date(at.Year(), at.Month(), at.Day()+1, 9, 0, 0, 0, at.Location())
	}
	return at
}

// businessDay moves at past weekends and the country's holidays.
func businessDay(at time.Time, country string) time.Time {
	for at.Weekday() == time.Saturday || at.Weekday() == time.Sunday || isHoliday(at, country) {
		at = at.Add(24 * time.Hour)
	}
	return at
}
GO

IFS= read -r -d '' SCHEDULER <<'GO' || true
package dunning

import (
	"time"

	"example.com/collections/internal/accounts"
)

// Invoice is an unpaid invoice.
type Invoice struct {
	ID          string
	Account     string
	Due         time.Time
	Attempts    []Attempt
	LastDecline Decline
}

// Step is one thing to do for an overdue invoice: "retry", "email", "suspend" or "cancel".
type Step struct {
	Invoice string
	Action  string
	At      time.Time
}

// Scheduler plans the dunning steps for overdue invoices.
type Scheduler struct {
	Accounts *accounts.Store
	Grace    time.Duration  #@7
}

// Plan returns what to do today about an overdue invoice.
func (s *Scheduler) Plan(inv Invoice, now time.Time) []Step {
	acct, ok := s.Accounts.Get(inv.Account)
	if !ok {  #@1-11
	if !ok || acct.Paused {  #@11
		return nil
	}
	overdue := now.Sub(inv.Due)
	if overdue <= 0 {  #@1-7
	if overdue <= s.Grace {  #@7
		return nil
	}
	var steps []Step
	days := int(overdue.Hours() / 24)
	switch {
	case days >= 30:
		if acct.Enterprise {
			steps = append(steps, Step{inv.ID, "email", now})
			if days >= 45 {
				if len(inv.Attempts) == 0 {
					steps = append(steps, Step{inv.ID, "email", now})
				} else {
					steps = append(steps, Step{inv.ID, "suspend", now})
				}
			}
		} else {
			steps = append(steps, Step{inv.ID, "cancel", now})
		}
	case days >= 14:
		steps = append(steps, Step{inv.ID, "suspend", now})
		if !acct.Enterprise {
			steps = append(steps, Step{inv.ID, "email", now})
		}
	default:
		for _, d := range []int{1, 3, 7} {
			if days == d {
				steps = append(steps, Step{inv.ID, "email", now})
			}
		}
		if inv.LastDecline.Code != "" {
			if at, retry := nextAttempt(inv.LastDecline, inv.Attempts, now); retry {
				steps = append(steps, Step{inv.ID, "retry", at})
			}
		}
	}
	if now.Weekday() == time.Saturday || now.Weekday() == time.Sunday {  #@3
		for i := range steps {  #@3
			if steps[i].Action == "email" {  #@3
				steps[i].At = now.AddDate(0, 0, int(8-now.Weekday())%7)  #@3
			}  #@3
		}  #@3
	}  #@3
	return steps
}
GO

IFS= read -r -d '' HOLIDAYS <<'GO' || true
package dunning

import "time"

// holidays are the days, as month-day, on which banks in each country don't settle card payments.
var holidays = map[string][]string{
	"DE": {"01-01", "05-01", "10-03", "12-25", "12-26"},
	"GB": {"01-01", "12-25", "12-26"},
	"US": {"01-01", "07-04", "12-25"},
}

func isHoliday(t time.Time, country string) bool {
	md := t.Format("01-02")
	for _, h := range holidays[country] {
		if h == md {
			return true
		}
	}
	return false
}
GO

IFS= read -r -d '' NOTIFY <<'GO' || true
package dunning

import (
	"fmt"

	"example.com/collections/internal/accounts"
)

// Mailer sends email.
type Mailer interface {
	Send(to, subject, body string) error
}

// Remind emails the account's owner about an overdue invoice.
func Remind(m Mailer, a accounts.Account, inv Invoice, days int) error {
	subject := fmt.Sprintf("Invoice %s is %d days overdue", inv.ID, days)  #@5-17
	subject := fmt.Sprintf("Payment for invoice %s didn't go through", inv.ID)  #@17
	body := fmt.Sprintf("<p>We couldn't collect payment for invoice %s. Please update your card.</p>", inv.ID)  #@5-14
	body := fmt.Sprintf("Hello,\n\nWe couldn't collect payment for invoice %s, now %d days overdue. Please update your card in the billing settings.\n", inv.ID, days)  #@14
	return m.Send(a.Email, subject, body)
}
GO

IFS= read -r -d '' TESTS <<'GO' || true
package dunning

import (
	"testing"
	"time"

	"example.com/collections/internal/accounts"
)

func TestStolenCardIsNotRetried(t *testing.T) {
	if _, retry := nextAttempt(Decline{Code: "stolen_card"}, nil, time.Now()); retry {
		t.Fatal("a stolen card was retried")
	}
}

func TestRetryLandsOnAWeekdayInBusinessHours(t *testing.T) {
	friday := time.Date(2026, 3, 6, 20, 30, 0, 0, time.UTC)
	at, retry := nextAttempt(Decline{Code: "generic_decline", Network: "visa"}, nil, friday)
	if !retry || at.Weekday() != time.Monday || at.Hour() != 9 {
		t.Fatalf("retry at %v (%v), want Monday 09:00", at, retry)
	}
}

func TestOverdueSmallAccountIsCancelledAfter30Days(t *testing.T) {
	store := accounts.NewStore()
	store.Put(accounts.Account{ID: "a1"})
	now := time.Date(2026, 3, 4, 10, 0, 0, 0, time.UTC)
	steps := (&Scheduler{Accounts: store}).Plan(Invoice{ID: "i1", Account: "a1", Due: now.AddDate(0, 0, -31)}, now)
	if len(steps) != 1 || steps[0].Action != "cancel" {
		t.Fatalf("steps = %v", steps)
	}
}
GO

IFS= read -r -d '' MAIN <<'GO' || true
// Command collector prints today's dunning steps for the invoices in a JSON file.
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	"example.com/collections/internal/accounts"
	"example.com/collections/internal/dunning"
)

func main() {
	path := flag.String("invoices", "invoices.json", "overdue invoices, as a JSON array")
	dryRun := flag.Bool("dry-run", false, "only print the steps")  #@16
	flag.Parse()
	data, err := os.ReadFile(*path)
	if err != nil {
		log.Fatal(err)
	}
	var invoices []dunning.Invoice
	if err := json.Unmarshal(data, &invoices); err != nil {
		log.Fatalf("%s: %v", *path, err)
	}
	s := &dunning.Scheduler{Accounts: accounts.NewStore()}
	for _, inv := range invoices {
		for _, step := range s.Plan(inv, time.Now()) {
			fmt.Println(step.Invoice, step.Action, step.At.Format(time.RFC3339))
		}
	}
	if *dryRun {  #@16
		fmt.Println("dry run: nothing was sent")  #@16
	}  #@16
}
GO

IFS= read -r -d '' README <<'MD' || true
# collections

Plans what to do about overdue invoices: when to retry the card, when to email
the customer, and when to suspend or cancel.

    go run ./cmd/collector -invoices overdue.json

## Tests  #@9
  #@9
    go vet ./... && go test ./...  #@9
MD

commit 1 330 grace "Plan dunning steps for overdue invoices"
commit 2 310 grace "Retry generic declines after a day, Amex after two"
commit 3 295 piotr "Don't send reminder emails at weekends"
commit 4 280 piotr "Stop retrying fraudulent cards; quick retries for processing errors"
commit 5 262 yara "Reminder emails"
commit 6 248 yara "No retries on bank holidays"
commit 7 236 grace "Grace period before dunning starts"
commit 8 220 piotr "Fewer retries in India and Brazil"
commit 9 205 yara "Tests for retries and cancellation"
commit 10 190 grace "Stop retrying when the bank asks for authentication"
commit 11 176 piotr "Paused accounts get no dunning"
report_rev=$(git rev-parse HEAD)
report_tree=$(git rev-parse 'HEAD^{tree}')
report_end=$(git log -1 --format=%ct HEAD)
report_day=$(git log -1 --format=%cd --date=short HEAD)
f1_line=$(git show "HEAD:internal/dunning/retry.go" | grep -n '^func nextAttempt' | cut -d: -f1)
f2_line=$(git show "HEAD:internal/dunning/scheduler.go" | grep -n '^func (s \*Scheduler) Plan' | cut -d: -f1)
commit 12 150 yara "Split nextAttempt into one function per rule"
commit 13 128 grace "Amex generic declines wait three days"
commit 14 100 yara "Plain-text reminder emails"
commit 15 70 piotr "Account currency"
commit 16 40 grace "-dry-run flag"
commit 17 12 yara "Friendlier reminder subject"

IFS= read -r -d '' REPORT <<'MD' || true
Assessment complete

## Target and snapshot

- Mode: assess. Scope: the whole code base, which has no base and no diff.
- Revision: @REV@
- Tree: @TREE@ (not dirty, not shallow)
- History window: @START_ISO@ to @END_ISO@, the 365 days before the revision's committer time, merges excluded.

## Coverage

- Inventory: 10 files, all of class source (roles: 8 src, 1 test, 1 doc); no vendored, generated, lock or minified files.
- Read in full: every Go file under `internal/` and `cmd/`, `README.md`, `go.mod`.
- Recipes run: inventory, size, history, coupling, hotspots and gohealth, each matching its checksum; pyfuncs found no Python.
- Ran `go vet ./...` and `go test ./...` in a copy of the snapshot: both passed, 3 tests in `internal/dunning`.
- History complete. Nothing sampled.
- The repository's state was the same before and after the review.
- Left on this machine: Go's build cache grew by the gohealth build.

## Health profile

| Dimension | State | Key measurements | Interpretation |
|---|---|---|---|
| 1. Structural complexity | measured | longest function `nextAttempt` 55 lines, depth 4, 20 branches; `(*Scheduler).Plan` 51 lines, depth 4, 17 branches | Two long units hold the retry and escalation rules |
| 2. Dependencies | measured | 3 packages, `internal/dunning` fan-in 1, fan-out 1 | Small and acyclic |
| 3. Duplication | observed | none found | |
| 4. Type safety and contracts | observed | `cmd/collector` decodes the invoice file into typed structs | Input is a local file the operator supplies |
| 5. Test protection | observed | 3 tests in `internal/dunning` | Few tests for the number of retry rules |
| 6. Side effects and shared state | observed | none beyond the in-memory account store | |
| 7. Change history | measured | 11 commits; `retry.go` changed in 6, `scheduler.go` in 4 | Retry rules change most |
| 8. Agent self-check | observed | README lists `go vet ./... && go test ./...`, which runs offline | |

## Positive signals

- One offline verification command in the README.
- Packages are small, with one direction of import.

## Findings

### F1: `nextAttempt` holds every retry rule in one function

- Anchor: `complex-unit`, `internal/dunning/retry.go`, `nextAttempt`; location `internal/dunning/retry.go:@F1_LINE@`.
- Evidence: gohealth row `internal/dunning/retry.go nextAttempt 55 4 20`; the function mixes attempt limits per country, a wait per decline code, spacing between attempts, business hours and holidays, and `retry.go` changed in 6 of the 11 commits.
- Cost: every new decline code or country rule is an edit inside the same switch and the checks after it, and only two tests cover it.
- Next step: give each rule its own function, with a test per rule first. Verify with gohealth: no unit in `retry.go` over 25 lines.
- Status: Confirmed.

### F2: `(*Scheduler).Plan` decides every escalation in one function

- Anchor: `complex-unit`, `internal/dunning/scheduler.go`, `(*Scheduler).Plan`; location `internal/dunning/scheduler.go:@F2_LINE@`.
- Evidence: gohealth row `internal/dunning/scheduler.go (*Scheduler).Plan 51 4 17`; the overdue thresholds, enterprise exceptions, retries and weekend handling share one switch.
- Cost: a change to one escalation tier means reading all of them; one test covers it.
- Next step: add a test per tier, then consider one function per tier. Verify by rerunning gohealth.
- Status: Confirmed.

## Recommended improvement sequence

1. Add tests for each decline code and for each overdue tier.
2. Split `nextAttempt` into one function per rule (F1).
3. Revisit `Plan` once its tiers have tests (F2).

## Open questions

- None.

## Findings table

| ID | Severity | Blocks | Evidence | Location | Finding |
|---|---|---|---|---|---|
| F1 | Low | no | Confirmed | internal/dunning/retry.go:@F1_LINE@ | nextAttempt holds every retry rule in one 55-line function |
| F2 | Low | no | Confirmed | internal/dunning/scheduler.go:@F2_LINE@ | (*Scheduler).Plan decides every escalation tier in one 51-line function |

## Snapshot

```json code-health-snapshot
{"dirty":false,"findings":[{"id":"F1","path":"internal/dunning/retry.go","rule":"complex-unit","symbol":"nextAttempt"},{"id":"F2","path":"internal/dunning/scheduler.go","rule":"complex-unit","symbol":"(*Scheduler).Plan"}],"recipes":[{"name":"compare.sh","sha256":"dc814a8d908ef55ced9d0009236fb462b87ec2592aa564c6898aaee905d95b2e"},{"name":"coupling.sh","sha256":"3b0dda98790dbe346c85fcadd30b5b2775e44c73a24008b11972bf7339a0a33d"},{"name":"gohealth/go.mod","sha256":"a8bb1a87263110fa89da37562b271c5337fb8d6fa510c8f65d1ab2350d799c82"},{"name":"gohealth/main.go","sha256":"bcc98f309ddc4bb4909d8e0e3e07492b914f6ea6c5c322b66071f7f85da6e881"},{"name":"history.sh","sha256":"17194f5cc2b5d2b8fad0bbb82d0f659e1498959bc2ea01630fad8e87dcdf90e9"},{"name":"hotspots.sh","sha256":"7e8cd3341821a73be498e474ae5dc8ac5250178746a861288150cfb306672c9c"},{"name":"inventory.sh","sha256":"9efef34de1238becfe8f430217e99af52337c51d010fc06306ac9b06d2c223d8"},{"name":"pyfuncs.py","sha256":"fd307239ceb4fc3c5849e2e4d66b26fba57ccbb7d8f31fc2b6ae479cfdb07bb4"},{"name":"renames.sh","sha256":"bdfb7dc710eb37d5a132b6b4407c7c3a74d527e846913e77af6f1195e5aa5d66"},{"name":"size.sh","sha256":"c666573d67b67d11fa1a0e139452cb67d97d4ece0faa1b7af870f84dc3c0f72a"}],"revision":"@REV@","schema_version":1,"scope":["."],"shallow":false,"tree":"@TREE@","window":{"end":@END@,"start":@START@}}
```

## Cost

12 minutes before writing this report. 41 requests; output 18342 tokens; input 96 uncached, 61207 written to the cache, 1288410 read from it. These figures come from Claude Code's transcript and leave out the requests that write this report and send the reply.
MD

report_start=$((report_end - 31536000))
iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
printf '%s' "$REPORT" | sed -e "s/@REV@/$report_rev/g" -e "s/@TREE@/$report_tree/g" \
	-e "s/@START@/$report_start/g" -e "s/@END@/$report_end/g" \
	-e "s/@START_ISO@/$(iso "$report_start")/g" -e "s/@END_ISO@/$(iso "$report_end")/g" \
	-e "s/@F1_LINE@/$f1_line/g" -e "s/@F2_LINE@/$f2_line/g" > .notes/code-health/code-health-reviewer.md
touch -d "$report_day" .notes/code-health/code-health-reviewer.md 2>/dev/null || touch -t "$(echo "$report_day" | tr -d -)1200" .notes/code-health/code-health-reviewer.md
