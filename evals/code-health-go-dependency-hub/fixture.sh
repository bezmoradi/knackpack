#!/bin/bash
# A Go fleet service with a year of history. internal/common holds the IDs,
# money, positions, shifts, errors and formatting helpers that every other
# package uses: all eight other packages of the module import it, and it changed
# in 15 of the 22 commits, for reasons that have nothing to do with each other.
# Each commit writes every file at its step: a line ending in "#@N" exists from
# step N on, and one ending in "#@N-M" from step N until step M.
set -euo pipefail
git init -q -b main
git config user.name "Mira Jensen"
git config user.email "mira@example.com"
now=$(date +%s)
mkdir -p cmd/fleetd internal/api internal/billing internal/common internal/dispatch internal/drivers internal/routing internal/telemetry internal/vehicles

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
	mira) name="Mira Jensen" email=mira@example.com ;;
	kwame) name="Kwame Boateng" email=kwame@example.com ;;
	sofia) name="Sofia Lindqvist" email=sofia@example.com ;;
	esac
	put "$1" 1 "$GOMOD" go.mod
	put "$1" 1 "$COMMON" internal/common/common.go
	put "$1" 1 "$GEO" internal/common/geo.go
	put "$1" 8 "$SHIFT" internal/common/shift.go
	put "$1" 6 "$COMMONTEST" internal/common/common_test.go
	put "$1" 2 "$DRIVERS" internal/drivers/drivers.go
	put "$1" 19 "$DRIVERSTEST" internal/drivers/drivers_test.go
	put "$1" 5 "$VEHICLES" internal/vehicles/vehicles.go
	put "$1" 4 "$ROUTING" internal/routing/routing.go
	put "$1" 7 "$BILLING" internal/billing/billing.go
	put "$1" 9 "$DISPATCH" internal/dispatch/dispatch.go
	put "$1" 11 "$TELEMETRY" internal/telemetry/telemetry.go
	put "$1" 13 "$API" internal/api/api.go
	put "$1" 13 "$MAIN" cmd/fleetd/main.go
	put "$1" 1 "$README" README.md
	git add -A
	GIT_AUTHOR_NAME=$name GIT_AUTHOR_EMAIL=$email GIT_COMMITTER_NAME=$name GIT_COMMITTER_EMAIL=$email \
		GIT_AUTHOR_DATE="$ts +0000" GIT_COMMITTER_DATE="$ts +0000" git commit -qm "$4"
}

IFS= read -r -d '' GOMOD <<'GO' || true
module example.com/fleet

go 1.22
GO

IFS= read -r -d '' COMMON <<'GO' || true
// Package common holds the types and helpers the fleet packages share.
package common

import (
	"errors"  #@2
	"fmt"
	"strings"  #@5
)

// VehicleID identifies a vehicle, such as "VH-0042".
type VehicleID string

// DriverID identifies a driver.
type DriverID string
  #@4
// JobID identifies a delivery job.  #@4
type JobID string  #@4
  #@14
// DepotID identifies a depot.  #@14
type DepotID string  #@14
  #@2
// ErrNotFound is returned for an ID that no record has.  #@2
var ErrNotFound = errors.New("not found")  #@2
  #@10
// ErrConflict is returned when a change clashes with an existing record.  #@10
var ErrConflict = errors.New("conflict")  #@10

// Money is an amount in cents, in one currency.
type Money struct {
	Cents    int64
	Currency string
}

// Add returns m+o; both must be in the same currency.
func (m Money) Add(o Money) (Money, error) {
	if m.Currency != o.Currency {
		return Money{}, fmt.Errorf("can't add %s to %s", o.Currency, m.Currency)
	}
	return Money{m.Cents + o.Cents, m.Currency}, nil
}
  #@7
// Sub returns m-o; both must be in the same currency.  #@7
func (m Money) Sub(o Money) (Money, error) {  #@7
	return m.Add(Money{-o.Cents, o.Currency})  #@7
}  #@7
  #@16
// Mul returns m times n.  #@16
func (m Money) Mul(n int64) Money {  #@16
	return Money{m.Cents * n, m.Currency}  #@16
}  #@16

func (m Money) String() string {
	sign, c := "", m.Cents
	if c < 0 {
		sign, c = "-", -c
	}
	return fmt.Sprintf("%s%d.%02d %s", sign, c/100, c%100, m.Currency)
}
  #@5
// NormalizePlate uppercases a licence plate and drops its spaces and dashes.  #@5
func NormalizePlate(p string) string {  #@5
	return strings.ToUpper(strings.NewReplacer(" ", "", "-", "").Replace(p))  #@5
}  #@5
  #@20
// FormatMinutes writes a number of minutes as hours and minutes, such as "1h05".  #@20
func FormatMinutes(m int) string {  #@20
	return fmt.Sprintf("%dh%02d", m/60, m%60)  #@20
}  #@20
GO

IFS= read -r -d '' GEO <<'GO' || true
package common

import "math"

// Point is a position in degrees.
type Point struct {
	Lat, Lon float64
}
  #@12
// Valid reports whether p is a position on Earth.  #@12
func (p Point) Valid() bool {  #@12
	return p.Lat >= -90 && p.Lat <= 90 && p.Lon >= -180 && p.Lon <= 180  #@12
}  #@12

// DistanceKm is the great-circle distance between a and b.
func DistanceKm(a, b Point) float64 {
	const earthKm = 6371.0
	la1, la2 := a.Lat*math.Pi/180, b.Lat*math.Pi/180
	dLat, dLon := la2-la1, (b.Lon-a.Lon)*math.Pi/180
	h := math.Sin(dLat/2)*math.Sin(dLat/2) + math.Cos(la1)*math.Cos(la2)*math.Sin(dLon/2)*math.Sin(dLon/2)
	return 2 * earthKm * math.Asin(math.Sqrt(h))  #@1-21
	return 2 * earthKm * math.Asin(math.Min(1, math.Sqrt(h)))  #@21
}
  #@18
// TravelMinutes is how long d km takes at kmh, rounded up.  #@18
func TravelMinutes(d, kmh float64) int {  #@18
	return int(math.Ceil(d / kmh * 60))  #@18
}  #@18
GO

IFS= read -r -d '' SHIFT <<'GO' || true
package common

import "time"

// Shift is a daily working window, in minutes after local midnight.
type Shift struct {
	Start, End int
}

// Covers reports whether t falls inside the shift; a shift may run past midnight.
func (s Shift) Covers(t time.Time) bool {
	m := t.Hour()*60 + t.Minute()
	if s.Start <= s.End {
		return m >= s.Start && m < s.End
	}
	return m >= s.Start || m < s.End
}
GO

IFS= read -r -d '' COMMONTEST <<'GO' || true
package common

import (
	"math"
	"testing"
	"time"  #@17
)

func TestDistanceKm(t *testing.T) {
	copenhagen, aarhus := Point{55.676, 12.568}, Point{56.157, 10.211}
	if d := DistanceKm(copenhagen, aarhus); math.Abs(d-156) > 2 {
		t.Errorf("Copenhagen to Aarhus = %.0f km, want about 156", d)
	}
}

func TestMoneyString(t *testing.T) {
	for _, c := range []struct {
		m    Money
		want string
	}{
		{Money{12345, "DKK"}, "123.45 DKK"},
		{Money{-5, "EUR"}, "-0.05 EUR"},
	} {
		if got := c.m.String(); got != c.want {
			t.Errorf("%#v.String() = %q, want %q", c.m, got, c.want)
		}
	}
}
  #@17
func TestShiftAcrossMidnight(t *testing.T) {  #@17
	night := Shift{Start: 22 * 60, End: 6 * 60}  #@17
	if !night.Covers(time.Date(2026, 1, 1, 23, 30, 0, 0, time.UTC)) || night.Covers(time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)) {  #@17
		t.Error("a 22:00 to 06:00 shift should cover 23:30 and not noon")  #@17
	}  #@17
}  #@17
GO

IFS= read -r -d '' DRIVERS <<'GO' || true
// Package drivers keeps the fleet's drivers.
package drivers

import (
	"sync"
	"time"  #@8

	"example.com/fleet/internal/common"
)

// Driver is one driver.
type Driver struct {
	ID    common.DriverID
	Name  string
	Phone string
	Shift common.Shift  #@8
}

// Registry holds drivers in memory.
type Registry struct {
	mu      sync.RWMutex
	drivers map[common.DriverID]Driver
}

// NewRegistry returns an empty registry.
func NewRegistry() *Registry {
	return &Registry{drivers: make(map[common.DriverID]Driver)}
}

// Put adds or replaces a driver.
func (r *Registry) Put(d Driver) {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.drivers[d.ID] = d
}

// Get returns the driver with the given ID.
func (r *Registry) Get(id common.DriverID) (Driver, error) {
	r.mu.RLock()
	defer r.mu.RUnlock()
	d, ok := r.drivers[id]
	if !ok {
		return Driver{}, common.ErrNotFound
	}
	return d, nil
}
  #@8
// OnShift returns the drivers whose shift covers t.  #@8
func (r *Registry) OnShift(t time.Time) []Driver {  #@8
	r.mu.RLock()  #@8
	defer r.mu.RUnlock()  #@8
	var out []Driver  #@8
	for _, d := range r.drivers {  #@8
		if d.Shift.Covers(t) {  #@8
			out = append(out, d)  #@8
		}  #@8
	}  #@8
	return out  #@8
}  #@8
GO

IFS= read -r -d '' DRIVERSTEST <<'GO' || true
package drivers

import (
	"errors"
	"testing"
	"time"

	"example.com/fleet/internal/common"
)

func TestOnShift(t *testing.T) {
	r := NewRegistry()
	r.Put(Driver{ID: "d1", Shift: common.Shift{Start: 8 * 60, End: 16 * 60}})
	r.Put(Driver{ID: "d2", Shift: common.Shift{Start: 16 * 60, End: 24 * 60}})
	on := r.OnShift(time.Date(2026, 1, 1, 9, 0, 0, 0, time.UTC))
	if len(on) != 1 || on[0].ID != "d1" {
		t.Fatalf("on shift at 09:00: %v", on)
	}
}

func TestGetUnknown(t *testing.T) {
	if _, err := NewRegistry().Get("nobody"); !errors.Is(err, common.ErrNotFound) {
		t.Fatalf("err = %v", err)
	}
}
GO

IFS= read -r -d '' VEHICLES <<'GO' || true
// Package vehicles keeps the fleet's vehicles.
package vehicles

import (
	"sync"

	"example.com/fleet/internal/common"
)

// Vehicle is one van or truck.
type Vehicle struct {
	ID         common.VehicleID
	Plate      string
	CapacityKg int
	Depot      common.DepotID  #@14
}

// Fleet holds vehicles in memory.
type Fleet struct {
	mu       sync.RWMutex
	vehicles map[common.VehicleID]Vehicle
}

// NewFleet returns an empty fleet.
func NewFleet() *Fleet {
	return &Fleet{vehicles: make(map[common.VehicleID]Vehicle)}
}

// Add registers a vehicle, normalizing its plate.
func (f *Fleet) Add(v Vehicle) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	v.Plate = common.NormalizePlate(v.Plate)
	for _, other := range f.vehicles {  #@10
		if other.Plate == v.Plate && other.ID != v.ID {  #@10
			return common.ErrConflict  #@10
		}  #@10
	}  #@10
	f.vehicles[v.ID] = v
	return nil
}

// Get returns the vehicle with the given ID.
func (f *Fleet) Get(id common.VehicleID) (Vehicle, error) {
	f.mu.RLock()
	defer f.mu.RUnlock()
	v, ok := f.vehicles[id]
	if !ok {
		return Vehicle{}, common.ErrNotFound
	}
	return v, nil
}
  #@14
// AtDepot returns the vehicles based at depot.  #@14
func (f *Fleet) AtDepot(depot common.DepotID) []Vehicle {  #@14
	f.mu.RLock()  #@14
	defer f.mu.RUnlock()  #@14
	var out []Vehicle  #@14
	for _, v := range f.vehicles {  #@14
		if v.Depot == depot {  #@14
			out = append(out, v)  #@14
		}  #@14
	}  #@14
	return out  #@14
}  #@14
GO

IFS= read -r -d '' ROUTING <<'GO' || true
// Package routing orders a vehicle's stops and estimates how long they take.
package routing

import "example.com/fleet/internal/common"

// Stop is one place a vehicle must visit.
type Stop struct {
	Job common.JobID
	At  common.Point
}

// Order returns the stops in nearest-neighbour order from start.
func Order(start common.Point, stops []Stop) []Stop {
	left := append([]Stop(nil), stops...)
	out := make([]Stop, 0, len(stops))
	cur := start
	for len(left) > 0 {
		best := 0
		for i := range left {
			if common.DistanceKm(cur, left[i].At) < common.DistanceKm(cur, left[best].At) {
				best = i
			}
		}
		cur = left[best].At
		out = append(out, left[best])
		left = append(left[:best], left[best+1:]...)
	}
	return out
}
  #@18
// Minutes estimates how long the stops take, in order, at an average speed.  #@18
func Minutes(start common.Point, stops []Stop, kmh float64) int {  #@18
	total, cur := 0, start  #@18
	for _, s := range stops {  #@18
		total += common.TravelMinutes(common.DistanceKm(cur, s.At), kmh)  #@18
		cur = s.At  #@18
	}  #@18
	return total  #@18
}  #@18
GO

IFS= read -r -d '' BILLING <<'GO' || true
// Package billing prices jobs for customers.
package billing

import (
	"math"

	"example.com/fleet/internal/common"
)

// Tariff is a customer's price list.
type Tariff struct {
	Base     common.Money
	PerKm    common.Money
	Discount common.Money
}

// Price is what a job from one point to another costs: the base, plus the
// distance in whole km, less the discount.
func Price(t Tariff, from, to common.Point) (common.Money, error) {
	km := int64(math.Ceil(common.DistanceKm(from, to)))
	total, err := t.Base.Add(common.Money{Cents: t.PerKm.Cents * km, Currency: t.PerKm.Currency})  #@7-16
	total, err := t.Base.Add(t.PerKm.Mul(km))  #@16
	if err != nil {
		return common.Money{}, err
	}
	return total.Sub(t.Discount)
}
GO

IFS= read -r -d '' DISPATCH <<'GO' || true
// Package dispatch assigns jobs to a driver on shift and their vehicle.
package dispatch

import (
	"errors"
	"fmt"  #@12
	"time"

	"example.com/fleet/internal/common"
	"example.com/fleet/internal/drivers"
	"example.com/fleet/internal/routing"  #@18
	"example.com/fleet/internal/vehicles"
)

// Job is one delivery.
type Job struct {
	ID       common.JobID
	Pickup   common.Point
	WeightKg int
}

// Assignment is who takes a job, in which vehicle.
type Assignment struct {
	Job     common.JobID
	Driver  common.DriverID
	Vehicle common.VehicleID
	Minutes int  #@18
}

// ErrNoCapacity means no driver on shift has a vehicle that can take the job.
var ErrNoCapacity = errors.New("no driver and vehicle available")

// Dispatcher assigns jobs.
type Dispatcher struct {
	Drivers  *drivers.Registry
	Vehicles *vehicles.Fleet
	Depot    common.Point
	Pairing  map[common.DriverID]common.VehicleID
}

// Assign gives the job to the first driver on shift whose vehicle can carry it.
func (d *Dispatcher) Assign(job Job, now time.Time) (Assignment, error) {
	if !job.Pickup.Valid() {  #@12
		return Assignment{}, fmt.Errorf("job %s: pickup %v isn't a position", job.ID, job.Pickup)  #@12
	}  #@12
	for _, drv := range d.Drivers.OnShift(now) {
		vid, ok := d.Pairing[drv.ID]
		if !ok {
			continue
		}
		v, err := d.Vehicles.Get(vid)
		if errors.Is(err, common.ErrNotFound) {
			continue
		}
		if err != nil {
			return Assignment{}, err
		}
		if v.CapacityKg < job.WeightKg {
			continue
		}
		return Assignment{Job: job.ID, Driver: drv.ID, Vehicle: vid}, nil  #@9-18
		a := Assignment{Job: job.ID, Driver: drv.ID, Vehicle: vid}  #@18
		a.Minutes = routing.Minutes(d.Depot, []routing.Stop{{Job: job.ID, At: job.Pickup}}, 40)  #@18
		return a, nil  #@18
	}
	return Assignment{}, ErrNoCapacity
}
GO

IFS= read -r -d '' TELEMETRY <<'GO' || true
// Package telemetry keeps each vehicle's latest reported position.
package telemetry

import (
	"fmt"  #@12
	"sync"
	"time"

	"example.com/fleet/internal/common"
)

// Position is where a vehicle reported itself, and when.
type Position struct {
	Vehicle common.VehicleID
	At      common.Point
	Time    time.Time
}

// Tracker holds the latest position of each vehicle.
type Tracker struct {
	mu   sync.Mutex
	last map[common.VehicleID]Position
}

// NewTracker returns an empty tracker.
func NewTracker() *Tracker {
	return &Tracker{last: make(map[common.VehicleID]Position)}
}

// Report records p, unless the vehicle has already reported a later position.
func (t *Tracker) Report(p Position) error {
	if !p.At.Valid() {  #@12
		return fmt.Errorf("vehicle %s: %v isn't a position", p.Vehicle, p.At)  #@12
	}  #@12
	t.mu.Lock()
	defer t.mu.Unlock()
	if prev, ok := t.last[p.Vehicle]; ok && prev.Time.After(p.Time) {
		return nil
	}
	t.last[p.Vehicle] = p
	return nil
}

// Last returns the vehicle's latest position.
func (t *Tracker) Last(id common.VehicleID) (Position, error) {
	t.mu.Lock()
	defer t.mu.Unlock()
	p, ok := t.last[id]
	if !ok {
		return Position{}, common.ErrNotFound
	}
	return p, nil
}
GO

IFS= read -r -d '' API <<'GO' || true
// Package api serves the fleet's HTTP API.
package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"example.com/fleet/internal/billing"
	"example.com/fleet/internal/common"
	"example.com/fleet/internal/dispatch"
	"example.com/fleet/internal/drivers"
	"example.com/fleet/internal/telemetry"  #@15
)

// Server holds what the handlers need.
type Server struct {
	Dispatch *dispatch.Dispatcher
	Drivers  *drivers.Registry
	Tariffs  map[string]billing.Tariff
	Tracker  *telemetry.Tracker  #@15
}

// Routes registers the handlers on mux.
func (s *Server) Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /jobs", s.createJob)
	mux.HandleFunc("GET /drivers/{id}", s.getDriver)
	mux.HandleFunc("POST /quotes", s.quote)
	mux.HandleFunc("POST /positions", s.reportPosition)  #@15
}

func (s *Server) createJob(w http.ResponseWriter, r *http.Request) {
	var job dispatch.Job
	if err := json.NewDecoder(r.Body).Decode(&job); err != nil {
		http.Error(w, "bad job", http.StatusBadRequest)
		return
	}
	a, err := s.Dispatch.Assign(job, time.Now())
	if errors.Is(err, dispatch.ErrNoCapacity) {
		http.Error(w, err.Error(), http.StatusConflict)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeJSON(w, http.StatusCreated, a)  #@13-20
	writeJSON(w, http.StatusCreated, map[string]any{"assignment": a, "eta": common.FormatMinutes(a.Minutes)})  #@20
}

func (s *Server) getDriver(w http.ResponseWriter, r *http.Request) {
	d, err := s.Drivers.Get(common.DriverID(r.PathValue("id")))
	if errors.Is(err, common.ErrNotFound) {
		http.NotFound(w, r)
		return
	}
	writeJSON(w, http.StatusOK, d)
}

func (s *Server) quote(w http.ResponseWriter, r *http.Request) {
	var q struct {
		Customer string
		From, To common.Point
	}
	if err := json.NewDecoder(r.Body).Decode(&q); err != nil || !q.From.Valid() || !q.To.Valid() {
		http.Error(w, "bad quote request", http.StatusBadRequest)
		return
	}
	t, ok := s.Tariffs[q.Customer]
	if !ok {
		http.NotFound(w, r)
		return
	}
	price, err := billing.Price(t, q.From, q.To)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"price": price.String()})
}
  #@15
func (s *Server) reportPosition(w http.ResponseWriter, r *http.Request) {  #@15
	var p telemetry.Position  #@15
	if err := json.NewDecoder(r.Body).Decode(&p); err != nil {  #@15
		http.Error(w, "bad position", http.StatusBadRequest)  #@15
		return  #@15
	}  #@15
	if err := s.Tracker.Report(p); err != nil {  #@15
		http.Error(w, err.Error(), http.StatusBadRequest)  #@15
		return  #@15
	}  #@15
	w.WriteHeader(http.StatusNoContent)  #@15
}  #@15

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}
GO

IFS= read -r -d '' MAIN <<'GO' || true
// Command fleetd serves the fleet API.
package main

import (
	"log"
	"net/http"
	"time"

	"example.com/fleet/internal/api"
	"example.com/fleet/internal/billing"
	"example.com/fleet/internal/common"
	"example.com/fleet/internal/dispatch"
	"example.com/fleet/internal/drivers"
	"example.com/fleet/internal/telemetry"  #@15
	"example.com/fleet/internal/vehicles"
)

func main() {
	reg := drivers.NewRegistry()
	srv := &api.Server{
		Dispatch: &dispatch.Dispatcher{
			Drivers:  reg,
			Vehicles: vehicles.NewFleet(),
			Depot:    common.Point{Lat: 55.676, Lon: 12.568},
			Pairing:  map[common.DriverID]common.VehicleID{},
		},
		Drivers: reg,
		Tariffs: map[string]billing.Tariff{},
		Tracker: telemetry.NewTracker(),  #@15
	}
	mux := http.NewServeMux()
	srv.Routes(mux)
	handler := logRequests(mux)  #@22
	s := &http.Server{Addr: "127.0.0.1:8080", Handler: mux, ReadHeaderTimeout: 10 * time.Second}  #@13-22
	s := &http.Server{Addr: "127.0.0.1:8080", Handler: handler, ReadHeaderTimeout: 10 * time.Second}  #@22
	log.Fatal(s.ListenAndServe())
}
  #@22
func logRequests(next http.Handler) http.Handler {  #@22
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {  #@22
		start := time.Now()  #@22
		next.ServeHTTP(w, r)  #@22
		log.Printf("%s %s %s", r.Method, r.URL.Path, time.Since(start))  #@22
	})  #@22
}  #@22
GO

IFS= read -r -d '' README <<'MD' || true
# fleet

Assigns delivery jobs to drivers and vans, prices them, and tracks where the
vans are.
  #@3
- `internal/common`: IDs, money, positions and shared helpers  #@3
- `internal/drivers`, `internal/vehicles`: who and what we have  #@3
- `internal/routing`, `internal/dispatch`: who goes where  #@3
- `internal/billing`: what a job costs  #@3

    go vet ./... && go test ./...
MD

commit 1 330 mira "Shared ID, money and position types"
commit 2 318 mira "Driver registry"
commit 3 305 kwame "README: package layout"
commit 4 296 kwame "Order a vehicle's stops"
commit 5 284 sofia "Vehicle fleet with normalized plates"
commit 6 270 mira "Test distances and money formatting"
commit 7 258 kwame "Price jobs per km"
commit 8 244 sofia "Driver shifts"
commit 9 231 mira "Assign jobs to a driver on shift"
commit 10 217 sofia "Plates are unique across the fleet"
commit 11 200 kwame "Track vehicle positions"
commit 12 186 sofia "Reject positions that aren't on Earth"
commit 13 170 mira "HTTP API and fleetd"
commit 14 151 kwame "Vehicles belong to a depot"
commit 15 133 sofia "POST /positions"
commit 16 115 kwame "Money.Mul for per-km prices"
commit 17 96 mira "Test shifts that run past midnight"
commit 18 78 kwame "Estimate travel time for each assignment"
commit 19 60 sofia "Driver registry tests"
commit 20 41 mira "Show the ETA as hours and minutes"
commit 21 22 kwame "Clamp rounding error in DistanceKm"
commit 22 8 sofia "Log each request's duration"
