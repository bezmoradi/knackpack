#!/bin/bash
# A small static dashboard. Each card clips its overflow to keep rounded
# corners, so the account menu that opens from a card header is cut off at the
# card's edge. The user asks for a CSS fix, which is CSS engineering, not a
# review.
set -euo pipefail
git init -q -b main
git config user.name "Dana Kowalski"
git config user.email "dana@example.com"
mkdir -p styles
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Team dashboard</title>
  <link rel="stylesheet" href="styles/base.css">
  <link rel="stylesheet" href="styles/cards.css">
</head>
<body>
  <main class="grid">
    <section class="card">
      <header class="card__header">
        <h2>Billing</h2>
        <div class="menu">
          <button class="menu__toggle" aria-expanded="true" aria-controls="billing-menu">Account</button>
          <ul class="menu__list" id="billing-menu">
            <li><a href="/billing/invoices">Invoices</a></li>
            <li><a href="/billing/cards">Payment cards</a></li>
            <li><a href="/billing/plan">Change plan</a></li>
          </ul>
        </div>
      </header>
      <p class="card__body">Next invoice on 1 December.</p>
    </section>
    <section class="card">
      <header class="card__header"><h2>Usage</h2></header>
      <p class="card__body">1,204 builds this month.</p>
    </section>
  </main>
</body>
</html>
HTML
cat > styles/base.css <<'CSS'
:root {
  --radius: 12px;
  --surface: #fff;
  --border: #d8dce3;
  --space: 1rem;
}
body { margin: 0; font: 16px/1.5 system-ui, sans-serif; background: #f3f5f8; }
.grid { display: grid; gap: var(--space); padding: var(--space); grid-template-columns: repeat(auto-fill, minmax(18rem, 1fr)); }
CSS
cat > styles/cards.css <<'CSS'
.card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: var(--radius);
  overflow: hidden;
}
.card__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--space);
  background: #eef1f6;
}
.card__body { padding: var(--space); margin: 0; }
.menu { position: relative; }
.menu__list {
  position: absolute;
  top: 100%;
  right: 0;
  min-width: 12rem;
  margin: 0;
  padding: 0.25rem 0;
  list-style: none;
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 8px;
}
.menu__list a { display: block; padding: 0.5rem 1rem; color: inherit; text-decoration: none; }
CSS
git add -A
git commit -qm "Dashboard cards with an account menu"
