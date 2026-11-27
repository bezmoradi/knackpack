#!/bin/bash
# A small Node service that takes payment webhooks. POST /webhooks/payments
# reads the raw body, verifySignature checks the HMAC header against
# payments.webhookSigningSecret from config/default.json, whose committed
# value is a real-looking secret, then handleEvent marks the order paid or
# refunded. The secret is put together at run time so that no file in this
# repository holds it whole.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-09T08:15:00Z" GIT_COMMITTER_DATE="2026-11-09T08:15:00Z"
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi@example.com"
mkdir -p src config

signing_secret=$(printf 'pwh_%s%s%s' 'Qm7tK2xV9bN4' 'rL8cW3zH6jP1' 'dF5sYa0uE2gT')

cat > README.md <<'EOF'
# payments-hooks

Receives the payment provider's webhooks and updates orders. Settings are in
`config/default.json`; `NODE_ENV=production` reads `config/production.json`
on top of it.

Run with `node src/server.js`.
EOF

cat > package.json <<'EOF'
{
  "name": "payments-hooks",
  "private": true,
  "type": "module",
  "dependencies": {
    "express": "4.21.1"
  }
}
EOF

cat > config/default.json <<EOF
{
  "port": 8080,
  "payments": {
    "webhookSigningSecret": "$signing_secret",
    "toleranceSeconds": 300
  },
  "orders": {
    "baseUrl": "http://localhost:7000"
  }
}
EOF

cat > src/config.js <<'EOF'
import { readFileSync } from "node:fs";

function load(name) {
  try {
    return JSON.parse(readFileSync(new URL(`../config/${name}.json`, import.meta.url)));
  } catch {
    return {};
  }
}

const base = load("default");
const env = process.env.NODE_ENV === "production" ? load("production") : {};

export const config = {
  ...base,
  ...env,
  payments: { ...base.payments, ...env.payments },
  orders: { ...base.orders, ...env.orders },
};
EOF

cat > src/signature.js <<'EOF'
import { createHmac, timingSafeEqual } from "node:crypto";

// The provider signs "<timestamp>.<raw body>" with HMAC-SHA256 and sends
// "t=<timestamp>,v1=<hex digest>" in the Payments-Signature header.
export function verifySignature(rawBody, header, secret, toleranceSeconds, now = Date.now()) {
  const parts = Object.fromEntries(
    String(header ?? "").split(",").map((kv) => kv.split("=", 2)),
  );
  const timestamp = Number(parts.t);
  if (!timestamp || !parts.v1) return false;
  if (Math.abs(now / 1000 - timestamp) > toleranceSeconds) return false;
  const expected = createHmac("sha256", secret).update(`${timestamp}.${rawBody}`).digest();
  const given = Buffer.from(parts.v1, "hex");
  return given.length === expected.length && timingSafeEqual(given, expected);
}
EOF

cat > src/orders.js <<'EOF'
import { config } from "./config.js";

async function post(path, body) {
  const res = await fetch(`${config.orders.baseUrl}${path}`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) throw new Error(`orders service answered ${res.status}`);
}

export const markPaid = (orderId, paymentId) => post(`/orders/${orderId}/paid`, { paymentId });
export const markRefunded = (orderId, amount) => post(`/orders/${orderId}/refunded`, { amount });
EOF

cat > src/server.js <<'EOF'
import express from "express";
import { config } from "./config.js";
import { markPaid, markRefunded } from "./orders.js";
import { verifySignature } from "./signature.js";

const app = express();

app.post("/webhooks/payments", express.raw({ type: "application/json" }), async (req, res) => {
  const ok = verifySignature(
    req.body.toString("utf8"),
    req.get("Payments-Signature"),
    config.payments.webhookSigningSecret,
    config.payments.toleranceSeconds,
  );
  if (!ok) {
    res.status(400).send("bad signature");
    return;
  }
  await handleEvent(JSON.parse(req.body));
  res.sendStatus(204);
});

async function handleEvent(event) {
  switch (event.type) {
    case "payment.succeeded":
      await markPaid(event.data.order_id, event.data.id);
      break;
    case "refund.succeeded":
      await markRefunded(event.data.order_id, event.data.amount);
      break;
    default:
      // Other event types are acknowledged and ignored.
      break;
  }
}

app.listen(config.port);
EOF

git add -A
git commit -qm "Payment webhooks: verify the signature and update orders"
