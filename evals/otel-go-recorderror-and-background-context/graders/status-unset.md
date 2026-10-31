---
type: llm
---

In the fixture, the uncommitted change to orders.go makes the createOrder handler start a span named orders.create with tracer.Start. When the payment charge fails, the handler calls span.RecordError(err), logs, and writes a 502, but never calls span.SetStatus, so the span's status stays Unset. The README says the on-call payment-failure panel counts orders.create spans whose status is Error.
PASS if the reply reports that RecordError only records the error as an event and doesn't set the span's status, so the failed orders.create span isn't marked as an error, and says the payment-failure path also needs span.SetStatus(codes.Error, ...) (with any message).
FAIL if it misses this, says RecordError marks the span as failed, or relies on otelhttp's server span being marked as an error instead of fixing the orders.create span.
