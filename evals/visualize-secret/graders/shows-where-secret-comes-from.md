---
type: llm
---

The user asked how a payments webhook is checked and handled. In the code, POST /webhooks/payments in src/server.js passes the raw body, the Payments-Signature header, config.payments.webhookSigningSecret and config.payments.toleranceSeconds to verifySignature (src/signature.js), which checks an HMAC-SHA256 of the timestamp and body; a bad signature gets 400, otherwise handleEvent calls markPaid or markRefunded (src/orders.js) on the orders service. The secret comes from config/default.json, overridden by config/production.json when NODE_ENV is production (src/config.js). This is Claude's final reply.
PASS if the reply shows the signature check in the flow and says where the signing secret comes from, naming the setting (webhookSigningSecret, or payments.webhookSigningSecret) or the config file it's read from.
FAIL if the reply leaves out the signature check, doesn't say where the secret comes from, or shows no flow. Count anything the reply doesn't show as a FAIL.
