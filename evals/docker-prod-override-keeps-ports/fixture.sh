#!/bin/bash
# A small Node API and its Postgres database, run with Docker Compose, with a
# committed compose.yaml for local development, plus an uncommitted change that
# adds a production override, compose.prod.yaml, and documents how production
# is deployed on a single VM.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p docs

cat > server.js <<'EOF'
'use strict';
const http = require('node:http');

const port = Number(process.env.PORT || 8080);

http
  .createServer((req, res) => {
    if (req.url === '/healthz') {
      res.writeHead(200, { 'content-type': 'text/plain' });
      res.end('ok\n');
      return;
    }
    res.writeHead(200, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ service: 'shop-api' }) + '\n');
  })
  .listen(port, '0.0.0.0', () => console.log(`listening on ${port}`));
EOF

cat > Dockerfile <<'EOF'
FROM node:22-slim
WORKDIR /app
COPY server.js ./
USER node
EXPOSE 8080
CMD ["node", "server.js"]
EOF

cat > compose.yaml <<'EOF'
services:
  api:
    build: .
    ports:
      - "8080:8080"
      # Node inspector, for local debugging.
      - "9229:9229"
    environment:
      DATABASE_URL: postgres://shop:${DB_PASSWORD}@db:5432/shop
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:17
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: shop
      POSTGRES_DB: shop
      POSTGRES_PASSWORD: ${DB_PASSWORD:?set DB_PASSWORD}
    volumes:
      - db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U shop -d shop"]
      interval: 5s
      timeout: 3s
      retries: 10

volumes:
  db-data:
EOF

cat > docs/deploy.md <<'EOF'
# Deploying

## Local development

    DB_PASSWORD=change-me docker compose up --build

The API is on http://localhost:8080, Postgres on localhost:5432 for a local
SQL client, and the Node inspector on port 9229.

## Production

Not set up yet.
EOF

git add -A
git commit -qm "Add the shop API and its local Compose stack"

cat > compose.prod.yaml <<'EOF'
# Production settings, applied on top of compose.yaml.
services:
  api:
    image: registry.example.com/shop/api:1.4.2
    # Loopback only: the TLS proxy on this host is the way in.
    ports:
      - "127.0.0.1:8080:8080"
    restart: unless-stopped

  db:
    restart: unless-stopped
EOF

cat > docs/deploy.md <<'EOF'
# Deploying

## Local development

    DB_PASSWORD=change-me docker compose up --build

The API is on http://localhost:8080, Postgres on localhost:5432 for a local
SQL client, and the Node inspector on port 9229.

## Production

Production is a single VM with a public IP, running Docker Engine 29. Deploy
from the repository's folder on the VM, with `DB_PASSWORD` set in the VM's
environment:

    docker compose -f compose.yaml -f compose.prod.yaml up -d

The VM's firewall, ufw, allows only ports 22 and 443. Only the API may be
reachable from outside the VM, and only through the TLS proxy that runs on the
same host and forwards port 443 to 127.0.0.1:8080. Postgres, the Node inspector
and anything else must not be reachable from the network.
EOF
