#!/bin/bash
# An English-only internal admin tool whose stylesheet uses physical
# properties throughout, plus an uncommitted, correct spacing tweak.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p public/css
cat > package.json <<'JSON'
{
  "name": "warehouse-admin",
  "private": true,
  "browserslist": ["Safari >= 15", "last 2 Chrome versions", "last 2 Firefox versions"]
}
JSON
cat > README.md <<'MD'
# warehouse-admin

Internal tool for the warehouse team. English only; no other locales are planned.
MD
cat > public/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Warehouse admin</title>
  <link rel="stylesheet" href="css/admin.css">
</head>
<body>
  <div class="shell">
    <nav class="shell__sidebar">
      <a class="shell__link" href="/stock">Stock</a>
      <a class="shell__link" href="/orders">Orders</a>
    </nav>
    <main class="shell__main">
      <h1>Stock</h1>
    </main>
  </div>
</body>
</html>
HTML
cat > public/css/admin.css <<'CSS'
body {
  margin: 0;
  font-family: system-ui, sans-serif;
}

.shell {
  display: flex;
  min-height: 100vh;
}

.shell__sidebar {
  display: flex;
  flex-direction: column;
  width: 14rem;
  padding-top: 1rem;
  background: #f3f4f6;
  border-right: 1px solid #d1d5db;
}

.shell__link {
  padding: 0.5rem 1rem;
  color: #1f2937;
  text-decoration: none;
}

.shell__link:hover {
  background: #e5e7eb;
}

.shell__main {
  flex: 1;
  padding: 1.5rem;
}
CSS
git add -A
git commit -qm "Admin shell"
cat > public/css/admin.css <<'CSS'
body {
  margin: 0;
  font-family: system-ui, sans-serif;
}

.shell {
  display: flex;
  min-height: 100vh;
}

.shell__sidebar {
  display: flex;
  flex-direction: column;
  width: 14rem;
  padding-top: 1rem;
  padding-right: 0.5rem;
  background: #f3f4f6;
  border-right: 1px solid #d1d5db;
}

.shell__link {
  margin-left: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 6px;
  color: #1f2937;
  text-decoration: none;
}

.shell__link:hover {
  background: #e5e7eb;
}

.shell__main {
  flex: 1;
  padding: 1.5rem;
}
CSS
