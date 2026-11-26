#!/bin/bash
# A small Express service that gives each shop the embed code for its reviews
# widget. src/snippet.js holds the snippet as raw markup: a <script> loaded
# from widgets.example.com, a <noscript> tracking <img> with an onerror
# handler, and, for pro shops, an <svg> badge with an onload handler and a
# remote link. GET /api/shops/:id/embed goes through findShop and
# renderSnippet, which escapes the shop's slug into the attributes.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-14T15:00:00Z" GIT_COMMITTER_DATE="2026-11-14T15:00:00Z"
git init -q -b main
git config user.name "Sam Rivera"
git config user.email "sam@example.com"
mkdir -p src

cat > README.md <<'EOF'
# embed-api

Gives each shop the embed code for the reviews widget, which the shop pastes
into its own site. The dashboard calls `GET /api/shops/:id/embed` and shows
the returned `html` in a copy box.

Run with `node src/server.js`.
EOF

cat > package.json <<'EOF'
{
  "name": "embed-api",
  "private": true,
  "type": "module",
  "dependencies": {
    "express": "4.21.1",
    "pg": "8.13.1"
  }
}
EOF

cat > src/server.js <<'EOF'
import express from "express";
import { findShop } from "./shops.js";
import { renderSnippet } from "./snippet.js";

const app = express();

app.get("/api/shops/:id/embed", async (req, res) => {
  const shop = await findShop(req.params.id);
  if (!shop) {
    res.status(404).json({ error: "shop_not_found" });
    return;
  }
  if (!shop.widgetEnabled) {
    res.status(409).json({ error: "widget_disabled" });
    return;
  }
  const html = renderSnippet(shop.slug, { badge: shop.plan === "pro" });
  res.json({ html });
});

app.listen(process.env.PORT ?? 3000);
EOF

cat > src/shops.js <<'EOF'
import pg from "pg";

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });

export async function findShop(id) {
  const { rows } = await pool.query(
    "SELECT id, slug, plan, widget_enabled FROM shops WHERE id = $1",
    [id],
  );
  if (rows.length === 0) return null;
  const r = rows[0];
  return { id: r.id, slug: r.slug, plan: r.plan, widgetEnabled: r.widget_enabled };
}
EOF

cat > src/snippet.js <<'EOF'
// The embed code a shop pastes into its own pages. {{shop}} is replaced with
// the shop's slug, escaped for an attribute value.
const WIDGET = `<div id="rv-reviews" data-shop="{{shop}}"></div>
<script async src="https://widgets.example.com/reviews/v3.js" data-shop="{{shop}}"></script>
<noscript><img src="https://widgets.example.com/p.gif?shop={{shop}}" width="1" height="1" alt="" onerror="this.remove()"></noscript>`;

// Pro shops also get the "verified reviews" badge.
const BADGE = `<a href="https://widgets.example.com/r/{{shop}}" rel="noopener">
<svg width="88" height="31" viewBox="0 0 88 31" onload="window.rvBadge && rvBadge(this)"><text x="6" y="20">Verified</text></svg>
</a>`;

function escapeAttr(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

export function renderSnippet(slug, { badge }) {
  const shop = escapeAttr(slug);
  const parts = [WIDGET];
  if (badge) parts.push(BADGE);
  return parts.join("\n").replaceAll("{{shop}}", shop);
}
EOF

git add -A
git commit -qm "Embed code endpoint for the reviews widget"
