#!/bin/bash
# A small Go HTTP service, orders, with OpenTelemetry tracing set up in main.go
# (tracer provider, TraceContext propagator, otelhttp). The uncommitted change
# instruments orders.go: the handler's span records a failed payment with
# RecordError but never sets its status, and the receipt goroutine starts its
# span from context.Background(), so it begins a new trace.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"

cat > go.mod <<'EOF'
module example.com/orders

go 1.26

require (
	go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.72.0
	go.opentelemetry.io/otel v1.47.0
	go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc v1.47.0
	go.opentelemetry.io/otel/sdk v1.47.0
)
EOF

cat > README.md <<'EOF'
# orders

The orders HTTP service. `POST /orders` charges the customer through the
payments service and answers 201, then emails a receipt in the background so
the response doesn't wait for the mail service.

## Telemetry

Traces go over OTLP to the platform Collector; the deployment sets
`OTEL_EXPORTER_OTLP_ENDPOINT`. The on-call payment-failure panel counts
`orders.create` spans whose status is Error, and a receipt's span should appear
in the same trace as the order that caused it.
EOF

cat > main.go <<'EOF'
// Command orders serves the orders API.
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/sdk/resource"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
	semconv "go.opentelemetry.io/otel/semconv/v1.43.0"
)

const serviceVersion = "1.6.0"

// setupTracing installs the global tracer provider and propagator. The
// exporter reads its endpoint and TLS settings from the OTEL_EXPORTER_OTLP_*
// variables the deployment sets.
func setupTracing(ctx context.Context) (func(context.Context) error, error) {
	exp, err := otlptracegrpc.New(ctx)
	if err != nil {
		return nil, err
	}
	res := resource.NewWithAttributes(semconv.SchemaURL,
		semconv.ServiceName("orders"),
		semconv.ServiceVersion(serviceVersion),
	)
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	return tp.Shutdown, nil
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	shutdownTracing, err := setupTracing(ctx)
	if err != nil {
		slog.Error("tracing setup failed", "err", err)
		os.Exit(1)
	}

	s := &server{
		payments: newHTTPPayments(os.Getenv("PAYMENTS_URL")),
		mailer:   newHTTPMailer(os.Getenv("MAILER_URL")),
	}
	mux := http.NewServeMux()
	mux.HandleFunc("POST /orders", s.createOrder)

	srv := &http.Server{
		Addr:              ":8080",
		Handler:           otelhttp.NewHandler(mux, "orders"),
		ReadHeaderTimeout: 5 * time.Second,
	}
	errc := make(chan error, 1)
	go func() { errc <- srv.ListenAndServe() }()

	select {
	case err := <-errc:
		slog.Error("server stopped", "err", err)
	case <-ctx.Done():
	}

	sctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(sctx); err != nil {
		slog.Error("server shutdown failed", "err", err)
	}
	if err := shutdownTracing(sctx); err != nil {
		slog.Error("tracing shutdown failed", "err", err)
	}
}
EOF

cat > clients.go <<'EOF'
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

type paymentClient interface {
	Charge(ctx context.Context, customerID string, amountCents int64) error
}

type mailer interface {
	SendReceipt(ctx context.Context, customerID, orderID string) error
}

// tracedClient sends outgoing requests through otelhttp, so they get client
// spans and carry the trace context.
var tracedClient = &http.Client{
	Transport: otelhttp.NewTransport(http.DefaultTransport),
	Timeout:   10 * time.Second,
}

type httpPayments struct{ baseURL string }

func newHTTPPayments(baseURL string) *httpPayments { return &httpPayments{baseURL: baseURL} }

func (p *httpPayments) Charge(ctx context.Context, customerID string, amountCents int64) error {
	return postJSON(ctx, p.baseURL+"/charges", map[string]any{
		"customer_id":  customerID,
		"amount_cents": amountCents,
	})
}

type httpMailer struct{ baseURL string }

func newHTTPMailer(baseURL string) *httpMailer { return &httpMailer{baseURL: baseURL} }

func (m *httpMailer) SendReceipt(ctx context.Context, customerID, orderID string) error {
	return postJSON(ctx, m.baseURL+"/receipts", map[string]any{
		"customer_id": customerID,
		"order_id":    orderID,
	})
}

func postJSON(ctx context.Context, url string, body any) error {
	b, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(b))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := tracedClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		return fmt.Errorf("POST %s: %s", url, resp.Status)
	}
	return nil
}
EOF

cat > orders.go <<'EOF'
package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"
)

type order struct {
	ID          string `json:"id"`
	CustomerID  string `json:"customer_id"`
	AmountCents int64  `json:"amount_cents"`
}

type server struct {
	payments paymentClient
	mailer   mailer
}

func (s *server) createOrder(w http.ResponseWriter, r *http.Request) {
	var o order
	if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
		http.Error(w, "invalid order", http.StatusBadRequest)
		return
	}

	if err := s.payments.Charge(r.Context(), o.CustomerID, o.AmountCents); err != nil {
		slog.ErrorContext(r.Context(), "payment failed", "order", o.ID, "err", err)
		http.Error(w, "payment failed", http.StatusBadGateway)
		return
	}

	// Send the receipt in the background so the response doesn't wait for
	// the mail service.
	go s.sendReceipt(o)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(o)
}

func (s *server) sendReceipt(o order) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := s.mailer.SendReceipt(ctx, o.CustomerID, o.ID); err != nil {
		slog.ErrorContext(ctx, "receipt failed", "order", o.ID, "err", err)
	}
}
EOF

git add -A
git commit -qm "Orders service with OpenTelemetry tracing set up"

cat > orders.go <<'EOF'
package main

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/codes"
)

var tracer = otel.Tracer("example.com/orders")

type order struct {
	ID          string `json:"id"`
	CustomerID  string `json:"customer_id"`
	AmountCents int64  `json:"amount_cents"`
}

type server struct {
	payments paymentClient
	mailer   mailer
}

func (s *server) createOrder(w http.ResponseWriter, r *http.Request) {
	ctx, span := tracer.Start(r.Context(), "orders.create")
	defer span.End()

	var o order
	if err := json.NewDecoder(r.Body).Decode(&o); err != nil {
		http.Error(w, "invalid order", http.StatusBadRequest)
		return
	}

	if err := s.payments.Charge(ctx, o.CustomerID, o.AmountCents); err != nil {
		span.RecordError(err)
		slog.ErrorContext(ctx, "payment failed", "order", o.ID, "err", err)
		http.Error(w, "payment failed", http.StatusBadGateway)
		return
	}

	// Send the receipt in the background so the response doesn't wait for
	// the mail service.
	go s.sendReceipt(context.Background(), o)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(o)
}

func (s *server) sendReceipt(ctx context.Context, o order) {
	ctx, span := tracer.Start(ctx, "orders.send_receipt")
	defer span.End()

	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	if err := s.mailer.SendReceipt(ctx, o.CustomerID, o.ID); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, "receipt not sent")
		slog.ErrorContext(ctx, "receipt failed", "order", o.ID, "err", err)
	}
}
EOF
