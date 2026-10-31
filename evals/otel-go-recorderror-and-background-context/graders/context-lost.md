---
type: llm
---

In the fixture, after a successful charge the createOrder handler in orders.go runs `go s.sendReceipt(context.Background(), o)`, and sendReceipt starts its span, orders.send_receipt, from that context. The span therefore has no parent and starts a new trace. The README says a receipt's span should appear in the same trace as the order that caused it. The receipt is sent in the background on purpose, and the request's context is canceled as soon as the handler returns.
PASS if the reply reports that passing context.Background() to the goroutine breaks the parent-child link (the receipt span starts a new trace, or isn't part of the order's trace), and suggests a fix that keeps the trace without tying the receipt to the request's cancellation, for example `context.WithoutCancel(ctx)`, a fresh context that carries the order span's span context (trace.ContextWithSpan or trace.ContextWithSpanContext), or a span link to the order's span.
FAIL if it misses the lost parentage, or its only suggested fix is passing the request's context (r.Context() or the handler's ctx) to the goroutine unchanged, without noting that it's canceled when the handler returns.
