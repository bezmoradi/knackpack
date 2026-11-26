#!/bin/bash
# A small Express app's session middleware in two commits. In the first,
# requireSession loads the session, rejects it once expiresAt has passed, and
# on every request pushes expiresAt to now + 30 minutes and saves it: a
# sliding expiry with no upper limit. The second commit, the last one, also
# rejects a session 12 hours after createdAt whatever the activity, and saves
# the new expiresAt only when more than 5 minutes have passed since lastSeen.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-10-28T09:00:00Z" GIT_COMMITTER_DATE="2026-10-28T09:00:00Z"
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi@example.com"
mkdir -p src

cat > README.md <<'EOF'
# portal

The customer portal's API. Sessions live in Redis (`src/sessions.js`); every
route under `/api` goes through `requireSession` in `src/auth.js`.
EOF

cat > package.json <<'EOF'
{
  "name": "portal",
  "private": true,
  "type": "module",
  "dependencies": {
    "express": "4.21.1",
    "redis": "4.7.0"
  }
}
EOF

cat > src/sessions.js <<'EOF'
import { createClient } from "redis";

const redis = createClient({ url: process.env.REDIS_URL });
await redis.connect();

export async function loadSession(id) {
  const raw = await redis.get(`session:${id}`);
  return raw ? JSON.parse(raw) : null;
}

export async function saveSession(session) {
  await redis.set(`session:${session.id}`, JSON.stringify(session), { PXAT: session.expiresAt });
}

export async function destroySession(id) {
  await redis.del(`session:${id}`);
}
EOF

cat > src/auth.js <<'EOF'
import { destroySession, loadSession, saveSession } from "./sessions.js";

const IDLE_MS = 30 * 60 * 1000;

// requireSession lets a request through with a live session and keeps the
// session alive while it's used.
export async function requireSession(req, res, next) {
  const id = req.cookies?.sid;
  const session = id && (await loadSession(id));
  if (!session) {
    res.status(401).json({ error: "no_session" });
    return;
  }
  const now = Date.now();
  if (now > session.expiresAt) {
    await destroySession(session.id);
    res.status(401).json({ error: "session_expired" });
    return;
  }
  session.expiresAt = now + IDLE_MS;
  session.lastSeen = now;
  await saveSession(session);
  req.session = session;
  next();
}
EOF

git add -A
git commit -qm "Session middleware with idle expiry"

export GIT_AUTHOR_DATE="2026-11-19T17:25:00Z" GIT_COMMITTER_DATE="2026-11-19T17:25:00Z"

cat > src/auth.js <<'EOF'
import { destroySession, loadSession, saveSession } from "./sessions.js";

const IDLE_MS = 30 * 60 * 1000;
const ABSOLUTE_MS = 12 * 60 * 60 * 1000;
const TOUCH_MS = 5 * 60 * 1000;

// requireSession lets a request through with a live session. A session ends
// after 30 idle minutes or 12 hours after sign-in, whichever comes first.
export async function requireSession(req, res, next) {
  const id = req.cookies?.sid;
  const session = id && (await loadSession(id));
  if (!session) {
    res.status(401).json({ error: "no_session" });
    return;
  }
  const now = Date.now();
  if (now > session.expiresAt || now - session.createdAt > ABSOLUTE_MS) {
    await destroySession(session.id);
    res.status(401).json({ error: "session_expired" });
    return;
  }
  // Write to Redis at most every 5 minutes per session.
  if (now - session.lastSeen > TOUCH_MS) {
    session.expiresAt = Math.min(now + IDLE_MS, session.createdAt + ABSOLUTE_MS);
    session.lastSeen = now;
    await saveSession(session);
  }
  req.session = session;
  next();
}
EOF

git add -A
git commit -qm "Sessions: 12-hour absolute limit, refresh at most every 5 minutes"
