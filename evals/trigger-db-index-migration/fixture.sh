#!/bin/bash
# A service with numbered SQL migrations for PostgreSQL. The user asks for the
# next migration, adding an index for a slow page, which is a change to make,
# not a database review.
set -euo pipefail
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi@example.com"
mkdir -p migrations
cat > migrations/0001_create_customers.sql <<'SQL'
CREATE TABLE customers (
    id bigserial PRIMARY KEY,
    email text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);
SQL
cat > migrations/0002_create_orders.sql <<'SQL'
CREATE TABLE orders (
    id bigserial PRIMARY KEY,
    customer_id bigint NOT NULL REFERENCES customers (id),
    total_cents bigint NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
SQL
cat > README.md <<'MD2'
# shop-db

Migrations run in file-name order with `migrate -path migrations -database "$DATABASE_URL" up`.
The order history page runs:

    SELECT id, total_cents, created_at FROM orders
    WHERE customer_id = $1 ORDER BY created_at DESC LIMIT 50;
MD2
git add -A
git commit -qm "Customers and orders"
