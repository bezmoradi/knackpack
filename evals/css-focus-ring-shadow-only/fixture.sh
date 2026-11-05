#!/bin/bash
# A web app with default focus outlines, plus an uncommitted change that draws
# focus only with box-shadow.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p web/styles
cat > web/styles/controls.css <<'CSS'
:root {
  --brand-500: #7c3aed;
  --brand-200: #ddd6fe;
}

.control {
  padding: 0.5rem 0.875rem;
  border: 1px solid #6b7280;
  border-radius: 8px;
  font: inherit;
  background: #ffffff;
}

.control--primary {
  border-color: var(--brand-500);
  color: #ffffff;
  background: var(--brand-500);
}
CSS
cat > web/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Invoices</title>
  <link rel="stylesheet" href="styles/controls.css">
</head>
<body>
  <form class="filters">
    <input class="control" type="search" name="q" aria-label="Search invoices">
    <button class="control control--primary" type="submit">Search</button>
    <a class="control" href="/invoices/new">New invoice</a>
  </form>
</body>
</html>
HTML
git add -A
git commit -qm "Form controls"
cat >> web/styles/controls.css <<'CSS'

.control:focus-visible {
  outline: none;
  box-shadow: 0 0 0 3px var(--brand-200), 0 0 0 5px var(--brand-500);
}
CSS
