---
type: llm
---

The fixture is a single small Python service, orders-api, at about 5 requests a second. Its README says traces go over OTLP/HTTP straight to a hosted tracing backend, and that the team has decided not to run an OpenTelemetry Collector because at this volume they don't want another component to deploy and watch. app.py sets service.name and service.version, uses a BatchSpanProcessor with the OTLP/HTTP exporter configured from OTEL_EXPORTER_OTLP_ENDPOINT and OTEL_EXPORTER_OTLP_HEADERS, and shuts the provider down in an atexit hook. Exporting directly is a valid design for this service.
Judge the severity the reply actually gives each problem it reports. An open question or unproven concern that says what severity it would have if confirmed isn't a finding rated at that severity, and "Blocks: no" isn't calling something blocking.
PASS if the reply doesn't report the missing Collector, a gateway tier, Kafka or a sidecar as a finding or a required change, and rates nothing about the export architecture High, Critical or blocking. Mentioning a Collector as an optional idea for later (for example if more services are added or tail sampling is needed) is fine, and so are unrelated findings at any severity.
FAIL if it reports exporting directly, or the lack of a Collector, gateway tier, Kafka or sidecar, as a defect or a required change, or rates anything about the export architecture High, Critical or blocking.
