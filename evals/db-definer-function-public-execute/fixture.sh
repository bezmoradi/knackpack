#!/bin/bash
# A small Python billing service on PostgreSQL 18 that keeps invoices for many
# organizations, with row-level security for its own role and a read-only role
# for support analysts. The uncommitted change moves voiding an invoice into a
# SECURITY DEFINER function and grants EXECUTE to the service's role, but never
# revokes the EXECUTE that PostgreSQL gives PUBLIC on every new function, so
# the read-only support role can void invoices; and the function sets no
# search_path, so a caller's temporary table named invoice_audit, with INSERT
# granted to PUBLIC, takes the audit row.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p app db migrations

cat > README.md <<'MD'
# billing

A small Python service that keeps invoices for many customer organizations in
PostgreSQL 18.

## Roles

`db/roles.sql` creates three roles:

- `billing_owner` owns the tables and runs the migrations.
- `billing_api` is the role the service connects as. It doesn't own the
  tables and doesn't bypass row-level security: the policies in migration
  0001 limit it to the organization in `app.org_id`, which the service sets
  at the start of each request's transaction.
- `support_ro` is the read-only role support analysts use in the SQL console
  to look up invoices and their history. It can read `invoices` and
  `invoice_audit` and must never change anything.

## Voiding invoices

Finance requires two things: only the billing service may void an invoice,
and every void leaves a row in `invoice_audit` saying who voided it and why.

## Migrations

Migrations in `migrations/` are plain SQL files, applied in order with
`psql` as `billing_owner`.
MD

cat > requirements.txt <<'TXT'
psycopg[binary]>=3.2,<4
TXT

cat > db/roles.sql <<'SQL'
-- Run once per environment by an administrator, before the migrations.
CREATE ROLE billing_owner LOGIN;
CREATE ROLE billing_api LOGIN;
CREATE ROLE support_ro LOGIN;
GRANT CREATE ON SCHEMA public TO billing_owner;
SQL

cat > migrations/0001_invoices.sql <<'SQL'
CREATE TABLE invoices (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    org_id       bigint      NOT NULL,
    number       text        NOT NULL,
    amount_cents bigint      NOT NULL,
    status       text        NOT NULL DEFAULT 'open'
                 CHECK (status IN ('open', 'paid', 'void')),
    voided_at    timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (org_id, number)
);

CREATE TABLE invoice_audit (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    invoice_id bigint      NOT NULL REFERENCES invoices (id),
    org_id     bigint      NOT NULL,
    action     text        NOT NULL,
    reason     text,
    actor      text        NOT NULL,
    at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX invoice_audit_invoice_idx ON invoice_audit (invoice_id);

ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY invoices_api ON invoices TO billing_api
    USING (org_id = current_setting('app.org_id')::bigint);
CREATE POLICY invoice_audit_api ON invoice_audit TO billing_api
    USING (org_id = current_setting('app.org_id')::bigint);

-- Support analysts read every organization's invoices, and nothing else.
CREATE POLICY invoices_support_read ON invoices FOR SELECT TO support_ro
    USING (true);
CREATE POLICY invoice_audit_support_read ON invoice_audit FOR SELECT TO support_ro
    USING (true);

GRANT USAGE ON SCHEMA public TO billing_api, support_ro;
GRANT SELECT, INSERT, UPDATE ON invoices TO billing_api;
GRANT SELECT, INSERT ON invoice_audit TO billing_api;
GRANT SELECT ON invoices, invoice_audit TO support_ro;
SQL

cat > app/__init__.py <<'PY'
PY

cat > app/invoices.py <<'PY'
"""Invoice operations.

Each function takes an open psycopg connection inside the request's
transaction, after the request handler has set app.org_id for it.
"""


def void_invoice(conn, invoice_id, reason, actor):
    """Void an open or paid invoice and record who did it and why.

    Returns False when the invoice doesn't exist in this organization or is
    already void.
    """
    row = conn.execute(
        "UPDATE invoices SET status = 'void', voided_at = now()"
        " WHERE id = %s AND status <> 'void' RETURNING org_id",
        (invoice_id,),
    ).fetchone()
    if row is None:
        return False
    conn.execute(
        "INSERT INTO invoice_audit (invoice_id, org_id, action, reason, actor)"
        " VALUES (%s, %s, 'void', %s, %s)",
        (invoice_id, row[0], reason, actor),
    )
    return True
PY

git add -A
git commit -qm "Invoices with row-level security per organization"

cat > migrations/0002_void_invoice_function.sql <<'SQL'
-- Voiding goes through one database function, so the status change and its
-- audit row are always written together and no caller can skip the audit row.
-- It runs as billing_owner so the audit insert works the same for every
-- caller, and it still checks the organization the request set.
CREATE FUNCTION void_invoice(p_invoice_id bigint, p_reason text, p_actor text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_org bigint;
BEGIN
    UPDATE invoices
       SET status = 'void', voided_at = now()
     WHERE id = p_invoice_id
       AND org_id = current_setting('app.org_id')::bigint
       AND status <> 'void'
    RETURNING org_id INTO v_org;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    INSERT INTO invoice_audit (invoice_id, org_id, action, reason, actor)
    VALUES (p_invoice_id, v_org, 'void', p_reason, p_actor);
    RETURN true;
END
$$;

-- Only the billing service voids invoices.
GRANT EXECUTE ON FUNCTION void_invoice(bigint, text, text) TO billing_api;
SQL

cat > app/invoices.py <<'PY'
"""Invoice operations.

Each function takes an open psycopg connection inside the request's
transaction, after the request handler has set app.org_id for it.
"""


def void_invoice(conn, invoice_id, reason, actor):
    """Void an open or paid invoice and record who did it and why.

    Returns False when the invoice doesn't exist in this organization or is
    already void. The database function writes the audit row.
    """
    (voided,) = conn.execute(
        "SELECT void_invoice(%s, %s, %s)", (invoice_id, reason, actor)
    ).fetchone()
    return voided
PY
