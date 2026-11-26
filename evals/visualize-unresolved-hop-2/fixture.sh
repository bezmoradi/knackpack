#!/bin/bash
# A small TypeScript reports CLI. `reports export <id> --format <f>` goes
# main -> fetchReportRows -> loadExporter(format) -> exporter.write ->
# uploadToBucket when --upload is given. loadExporter imports a module by the
# name a JSON map gives for the format: config/exporters.json by default, or
# the file REPORTS_EXPORTERS names, which the README says production sets.
# So the code doesn't settle which exporter module runs. src/scheduler.ts runs
# nightly exports through its own path and is not on the CLI path.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-06T13:20:00Z" GIT_COMMITTER_DATE="2026-11-06T13:20:00Z"
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/exporters config

cat > README.md <<'EOF'
# reports

`reports export <report-id> --format csv|xlsx|pdf [--out file] [--upload]`
writes a report to a file and, with `--upload`, to the reports bucket.

Which module writes each format is set in `config/exporters.json`. Production
sets `REPORTS_EXPORTERS=/etc/reports/exporters.json`, kept in the ops repo, to
use the licensed spreadsheet and PDF writers there.
EOF

cat > package.json <<'EOF'
{
  "name": "reports",
  "private": true,
  "type": "module",
  "bin": { "reports": "dist/cli.js" },
  "dependencies": {
    "@aws-sdk/client-s3": "3.700.0",
    "pg": "8.13.1"
  },
  "devDependencies": {
    "typescript": "5.6.3"
  }
}
EOF

cat > config/exporters.json <<'EOF'
{
  "formats": {
    "csv": "csv",
    "xlsx": "spreadsheet",
    "pdf": "pdf-basic"
  },
  "options": {
    "csv": { "delimiter": "," },
    "spreadsheet": { "sheetName": "Report" }
  }
}
EOF

cat > src/cli.ts <<'EOF'
import { parseArgs } from "node:util";
import { fetchReportRows } from "./db.js";
import { loadExporter } from "./exporters/index.js";
import { uploadToBucket } from "./storage.js";

async function main(argv: string[]): Promise<number> {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      format: { type: "string", default: "csv" },
      out: { type: "string" },
      upload: { type: "boolean", default: false },
    },
  });
  const [command, reportId] = positionals;
  if (command !== "export" || !reportId) {
    console.error("usage: reports export <report-id> --format csv|xlsx|pdf [--out file] [--upload]");
    return 2;
  }
  const format = values.format!;
  const out = values.out ?? `report-${reportId}.${format}`;
  const rows = await fetchReportRows(reportId);
  const exporter = await loadExporter(format);
  await exporter.write(rows, out);
  if (values.upload) {
    await uploadToBucket(out);
  }
  return 0;
}

main(process.argv.slice(2)).then((code) => process.exit(code));
EOF

cat > src/db.ts <<'EOF'
import pg from "pg";

const pool = new pg.Pool({ connectionString: process.env.REPORTS_DATABASE_URL });

export type Row = Record<string, string | number | null>;

export async function fetchReportRows(reportId: string): Promise<Row[]> {
  const { rows } = await pool.query("SELECT * FROM report_rows($1)", [reportId]);
  return rows;
}
EOF

cat > src/exporters/index.ts <<'EOF'
import { readFileSync } from "node:fs";
import type { Row } from "../db.js";

export interface Exporter {
  write(rows: Row[], path: string): Promise<void>;
}

interface ExporterMap {
  formats: Record<string, string>;
  options?: Record<string, Record<string, unknown>>;
}

function readMap(): ExporterMap {
  const file = process.env.REPORTS_EXPORTERS ?? new URL("../../config/exporters.json", import.meta.url);
  return JSON.parse(readFileSync(file, "utf8"));
}

export async function loadExporter(format: string): Promise<Exporter> {
  const map = readMap();
  const moduleName = map.formats[format];
  if (!moduleName) {
    throw new Error(`no exporter for format ${format}`);
  }
  const mod = await import(`./${moduleName}.js`);
  return new mod.default(map.options?.[moduleName] ?? {});
}
EOF

cat > src/exporters/csv.ts <<'EOF'
import { writeFile } from "node:fs/promises";
import type { Row } from "../db.js";
import type { Exporter } from "./index.js";

export default class CsvExporter implements Exporter {
  constructor(private readonly options: { delimiter?: string }) {}

  async write(rows: Row[], path: string): Promise<void> {
    const d = this.options.delimiter ?? ",";
    const header = rows.length ? Object.keys(rows[0]) : [];
    const lines = [header.join(d), ...rows.map((r) => header.map((h) => String(r[h] ?? "")).join(d))];
    await writeFile(path, lines.join("\n") + "\n");
  }
}
EOF

cat > src/exporters/spreadsheet.ts <<'EOF'
import { writeFile } from "node:fs/promises";
import type { Row } from "../db.js";
import type { Exporter } from "./index.js";

// A minimal SpreadsheetML writer; production maps xlsx to its own module.
export default class SpreadsheetExporter implements Exporter {
  constructor(private readonly options: { sheetName?: string }) {}

  async write(rows: Row[], path: string): Promise<void> {
    const name = this.options.sheetName ?? "Sheet1";
    const cells = rows.map((r) => Object.values(r).map((v) => `<c>${String(v ?? "")}</c>`).join(""));
    await writeFile(path, `<sheet name="${name}">${cells.map((c) => `<row>${c}</row>`).join("")}</sheet>`);
  }
}
EOF

cat > src/exporters/pdf-basic.ts <<'EOF'
import { writeFile } from "node:fs/promises";
import type { Row } from "../db.js";
import type { Exporter } from "./index.js";

// Plain-text PDF fallback for local use.
export default class BasicPdfExporter implements Exporter {
  constructor(_options: Record<string, unknown>) {}

  async write(rows: Row[], path: string): Promise<void> {
    const text = rows.map((r) => Object.values(r).join("  ")).join("\n");
    await writeFile(path, `%PDF-1.4\n% ${text.length} bytes of text\n${text}\n%%EOF\n`);
  }
}
EOF

cat > src/storage.ts <<'EOF'
import { readFile } from "node:fs/promises";
import { basename } from "node:path";
import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";

const s3 = new S3Client({});

export async function uploadToBucket(path: string): Promise<void> {
  await s3.send(
    new PutObjectCommand({
      Bucket: process.env.REPORTS_BUCKET ?? "reports-local",
      Key: `exports/${basename(path)}`,
      Body: await readFile(path),
    }),
  );
}
EOF

cat > src/scheduler.ts <<'EOF'
// Nightly exports, run by the ops cron with `node dist/scheduler.js`.
// Writes every scheduled report as CSV and uploads it; not used by the CLI.
import { fetchReportRows } from "./db.js";
import CsvExporter from "./exporters/csv.js";
import { uploadToBucket } from "./storage.js";

const SCHEDULED = (process.env.REPORTS_NIGHTLY ?? "").split(",").filter(Boolean);

for (const id of SCHEDULED) {
  const rows = await fetchReportRows(id);
  const out = `/tmp/nightly-${id}.csv`;
  await new CsvExporter({}).write(rows, out);
  await uploadToBucket(out);
}
EOF

git add -A
git commit -qm "Reports CLI: export to csv, xlsx or pdf, optional upload"
