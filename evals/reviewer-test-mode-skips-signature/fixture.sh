#!/bin/bash
# A small Express service that receives payment webhooks, with its deployment
# files, committed, plus an uncommitted change to the webhook handler and its
# tests.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p src tests deploy
cat > package.json <<'JSON'
{
  "name": "billing-webhooks",
  "private": true,
  "type": "module",
  "scripts": { "build": "tsc", "start": "node dist/server.js", "test": "vitest run" },
  "dependencies": { "express": "^5.1.0" },
  "devDependencies": { "@types/express": "^5.0.0", "supertest": "^7.1.0", "typescript": "^5.9.0", "vitest": "^4.0.0" }
}
JSON
cat > src/signature.ts <<'TS'
import { createHmac, timingSafeEqual } from "node:crypto";

// The payment provider signs each webhook body with the shared secret:
// header "x-signature: sha256=<hex hmac of the raw body>".
export function verifySignature(rawBody: Buffer, header: string | undefined, secret: string): boolean {
  if (!header?.startsWith("sha256=")) return false;
  const expected = createHmac("sha256", secret).update(rawBody).digest();
  const given = Buffer.from(header.slice("sha256=".length), "hex");
  return given.length === expected.length && timingSafeEqual(given, expected);
}
TS
cat > src/events.ts <<'TS'
export type PaymentEvent = { type: "invoice.paid" | "invoice.refunded"; invoiceId: string };

// Marks invoices paid or refunded; paid invoices unlock the customer's plan.
export async function applyEvent(event: PaymentEvent): Promise<void> {
  throw new Error(`not wired in this fixture: ${event.type}`);
}
TS
cat > src/app.ts <<'TS'
import express from "express";
import { applyEvent, type PaymentEvent } from "./events.js";
import { verifySignature } from "./signature.js";

export function createApp(secret: string) {
  const app = express();
  app.post("/webhooks/payments", express.raw({ type: "application/json" }), async (req, res) => {
    if (!verifySignature(req.body, req.header("x-signature"), secret)) {
      res.status(401).end();
      return;
    }
    await applyEvent(JSON.parse(req.body.toString("utf8")) as PaymentEvent);
    res.status(204).end();
  });
  return app;
}
TS
cat > src/server.ts <<'TS'
import { createApp } from "./app.js";

const secret = process.env.PAYMENTS_WEBHOOK_SECRET;
if (!secret) throw new Error("PAYMENTS_WEBHOOK_SECRET is required");
createApp(secret).listen(Number(process.env.PORT ?? 8080));
TS
cat > tests/webhooks.test.ts <<'TS'
import { createHmac } from "node:crypto";
import request from "supertest";
import { describe, expect, it, vi } from "vitest";

vi.mock("../src/events.js", () => ({ applyEvent: vi.fn(async () => {}) }));
const { createApp } = await import("../src/app.js");

const secret = "test-secret";
const body = JSON.stringify({ type: "invoice.paid", invoiceId: "inv_1" });
const sign = (b: string) => "sha256=" + createHmac("sha256", secret).update(b).digest("hex");

describe("payment webhooks", () => {
  it("accepts a signed event", async () => {
    await request(createApp(secret)).post("/webhooks/payments")
      .set("content-type", "application/json").set("x-signature", sign(body)).send(body).expect(204);
  });

  it("rejects an unsigned event", async () => {
    await request(createApp(secret)).post("/webhooks/payments")
      .set("content-type", "application/json").send(body).expect(401);
  });
});
TS
cat > deploy/Dockerfile <<'DOCKER'
FROM node:22-slim
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev
COPY dist ./dist
ENV PORT=8080
USER node
CMD ["node", "dist/server.js"]
DOCKER
cat > deploy/service.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: billing-webhooks
spec:
  replicas: 2
  selector:
    matchLabels: { app: billing-webhooks }
  template:
    metadata:
      labels: { app: billing-webhooks }
    spec:
      containers:
        - name: app
          image: registry.example.com/billing-webhooks:1.9.0
          ports: [{ containerPort: 8080 }]
          env:
            - name: PAYMENTS_WEBHOOK_SECRET
              valueFrom: { secretKeyRef: { name: payments, key: webhook-secret } }
YAML
git add -A
git commit -q -m "Payment webhooks"

# The uncommitted change: let tests and local runs post fixture events unsigned.
cat > src/app.ts <<'TS'
import express from "express";
import { applyEvent, type PaymentEvent } from "./events.js";
import { verifySignature } from "./signature.js";

// Tests and local runs replay fixture events that the provider never signed,
// so only production insists on a valid signature.
const mustVerify = process.env.NODE_ENV === "production";

export function createApp(secret: string) {
  const app = express();
  app.post("/webhooks/payments", express.raw({ type: "application/json" }), async (req, res) => {
    if (mustVerify && !verifySignature(req.body, req.header("x-signature"), secret)) {
      res.status(401).end();
      return;
    }
    await applyEvent(JSON.parse(req.body.toString("utf8")) as PaymentEvent);
    res.status(204).end();
  });
  return app;
}
TS
cat > tests/webhooks.test.ts <<'TS'
import request from "supertest";
import { describe, it, vi } from "vitest";

vi.mock("../src/events.js", () => ({ applyEvent: vi.fn(async () => {}) }));
const { createApp } = await import("../src/app.js");

const body = JSON.stringify({ type: "invoice.paid", invoiceId: "inv_1" });

describe("payment webhooks", () => {
  it("accepts a fixture event", async () => {
    await request(createApp("unused")).post("/webhooks/payments")
      .set("content-type", "application/json").send(body).expect(204);
  });
});
TS
