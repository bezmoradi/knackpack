#!/bin/bash
# A dashboard whose declared targets include Firefox ESR 128 and Safari 17,
# plus an uncommitted account menu placed only by CSS anchor positioning.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/styles src/components
cat > package.json <<'JSON'
{
  "name": "ops-dashboard",
  "private": true,
  "browserslist": [
    "last 2 Chrome versions",
    "last 2 Edge versions",
    "Firefox ESR",
    "Firefox >= 128",
    "Safari >= 17",
    "iOS >= 17"
  ]
}
JSON
cat > src/components/header.html <<'HTML'
<header class="app-header">
  <a class="app-header__logo" href="/">Ops</a>
  <button class="account-button" type="button" popovertarget="account-menu">Signed in as Dana</button>
  <div id="account-menu" class="account-menu" popover>
    <a href="/profile">Profile</a>
    <a href="/tokens">API tokens</a>
    <a href="/logout">Sign out</a>
  </div>
</header>
HTML
cat > src/styles/header.css <<'CSS'
.app-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.75rem 1.5rem;
  border-block-end: 1px solid #e5e7eb;
}

.account-button {
  padding: 0.5rem 0.75rem;
  border: 1px solid #9ca3af;
  border-radius: 6px;
  background: #ffffff;
}

.account-menu {
  display: grid;
  gap: 0.25rem;
  padding: 0.5rem;
  border: 1px solid #d1d5db;
  border-radius: 8px;
  background: #ffffff;
  box-shadow: 0 8px 24px rgb(0 0 0 / 0.12);
}
CSS
git add -A
git commit -qm "Header with account menu"
cat >> src/styles/header.css <<'CSS'

.account-button {
  anchor-name: --account-button;
}

.account-menu {
  position: absolute;
  position-anchor: --account-button;
  inset: auto;
  margin: 0;
  top: anchor(bottom);
  right: anchor(right);
  margin-block-start: 0.25rem;
  position-try-fallbacks: flip-block;
}
CSS
