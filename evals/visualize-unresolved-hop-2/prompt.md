---
description: 'A TypeScript reports CLI. reports export <id> --format xlsx --upload goes main (src/cli.ts) -> fetchReportRows (src/db.ts) -> loadExporter(format) -> exporter.write -> uploadToBucket (src/storage.ts). loadExporter (src/exporters/index.ts) imports ./<moduleName>.js by the name a JSON map gives for the format: config/exporters.json, which maps xlsx to spreadsheet, unless REPORTS_EXPORTERS names another file, which the README says production does. So the code doesn''t settle which module writes xlsx. src/scheduler.ts runs nightly CSV exports separately. With the skill, Claude labels the exporter hop Inferred or Unknown and invents nothing.'
expected_outcome: The exporter hop is shown as decided by the format map (and REPORTS_EXPORTERS) and labelled Inferred or Unknown, not as a plain edge to one module; nothing the code lacks, and not the scheduler, is on the path.
tags: [visualize, visualize-dev]
runs: 1
max_turns: 20
timeout_seconds: 900
allowed_tools: [Read, Glob, Grep, Skill]
---

/knackpack:visualize what runs when someone does `reports export <id> --format xlsx --upload`, from the CLI down to the file landing in the bucket.
