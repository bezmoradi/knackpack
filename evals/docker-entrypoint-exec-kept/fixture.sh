#!/bin/bash
# A Node export worker that takes jobs from a queue folder and writes each one
# to a CSV file, with its README and Compose service committed, plus an
# uncommitted change that adds the Dockerfile, an entrypoint script and a
# configuration check that the entrypoint runs before the worker.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p scripts

cat > package.json <<'EOF'
{
  "name": "export-worker",
  "version": "1.0.0",
  "private": true,
  "description": "Turns export jobs from the queue folder into CSV files.",
  "main": "worker.js",
  "scripts": {
    "start": "node worker.js"
  },
  "engines": {
    "node": ">=22"
  }
}
EOF

cat > worker.js <<'EOF'
'use strict';
// Takes export jobs from QUEUE_DIR one at a time and writes each one to
// EXPORT_DIR/<id>.csv. On SIGTERM it takes no new job, finishes the one it is
// on and exits.
const fs = require('node:fs/promises');
const path = require('node:path');

const queueDir = process.env.QUEUE_DIR;
const exportDir = process.env.EXPORT_DIR;
// Rows come from a slow upstream; a job of 200 rows takes 20 seconds.
const ROW_DELAY_MS = 100;

let stopping = false;

process.on('SIGTERM', () => {
  console.log('SIGTERM: finishing the current job, then exiting');
  stopping = true;
});

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function runJob(file) {
  const job = JSON.parse(await fs.readFile(path.join(queueDir, file), 'utf8'));
  const out = await fs.open(path.join(exportDir, `${job.id}.csv`), 'w');
  try {
    await out.write('row,amount\n');
    for (let i = 0; i < job.rows; i++) {
      await out.write(`${i},${(i * 7) % 100}\n`);
      await sleep(ROW_DELAY_MS);
    }
  } finally {
    await out.close();
  }
  await fs.unlink(path.join(queueDir, file));
  console.log(`exported ${job.id}`);
}

async function main() {
  console.log('worker started');
  while (!stopping) {
    const files = (await fs.readdir(queueDir)).filter((f) => f.endsWith('.json')).sort();
    if (files.length === 0) {
      await sleep(1000);
      continue;
    }
    await runJob(files[0]);
  }
  console.log('worker stopped cleanly');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
EOF

cat > README.md <<'EOF'
# export-worker

Takes export jobs from the queue folder one at a time and writes each one to a
CSV file in the exports folder, which the downstream import picks up.

- A job takes up to 20 seconds.
- A job must never be cut off halfway: the import can't tell a half-written
  export file from a finished one, and a half-written file breaks the import.
- On SIGTERM the worker takes no new job, finishes the one it's on and exits.
  Compose's `stop_grace_period: 30s` gives it that time, so `docker compose
  down`, `docker compose stop` and redeploys never cut a job off.

Run it with `docker compose up -d --build`.
EOF

cat > compose.yaml <<'EOF'
services:
  worker:
    build: .
    environment:
      QUEUE_DIR: /data/queue
      EXPORT_DIR: /data/exports
    volumes:
      - export-data:/data
    # A job takes up to 20 seconds; give the worker time to finish it on stop.
    stop_grace_period: 30s
    restart: unless-stopped

volumes:
  export-data:
EOF

git add -A
git commit -qm "Add the export worker and its Compose service"

cat > Dockerfile <<'EOF'
FROM node:22-slim
WORKDIR /app
COPY package.json worker.js docker-entrypoint.sh ./
COPY scripts ./scripts
RUN mkdir -p /data/queue /data/exports && chown -R node:node /data
USER node
ENTRYPOINT ["./docker-entrypoint.sh"]
EOF

cat > scripts/check-config.js <<'EOF'
'use strict';
// Exits non-zero, before the worker starts, if a folder the worker needs is
// missing or not writable.
const fs = require('node:fs');

let ok = true;
for (const name of ['QUEUE_DIR', 'EXPORT_DIR']) {
  const dir = process.env[name];
  if (!dir) {
    console.error(`${name} is not set`);
    ok = false;
    continue;
  }
  try {
    fs.accessSync(dir, fs.constants.R_OK | fs.constants.W_OK);
  } catch (err) {
    console.error(`${name}=${dir} is not a writable folder: ${err.code}`);
    ok = false;
  }
}
process.exit(ok ? 0 : 1);
EOF

cat > docker-entrypoint.sh <<'EOF'
#!/bin/sh
set -e

# Fail fast, with a clear message, if the configuration is incomplete.
node scripts/check-config.js

# exec, so the worker replaces this shell and gets the stop signal itself.
exec node worker.js
EOF
chmod +x docker-entrypoint.sh
