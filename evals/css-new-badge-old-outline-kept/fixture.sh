#!/bin/bash
# An admin stylesheet whose committed legacy rules already remove focus
# outlines, plus an uncommitted, correct status badge.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p static/css
cat > static/css/admin.css <<'CSS'
body {
  margin: 0;
  font-family: system-ui, sans-serif;
  color: #111827;
}

/* legacy: kept from the 2019 theme */
a:focus,
button:focus {
  outline: 0;
}

.order-table {
  inline-size: 100%;
  border-collapse: collapse;
}

.order-table th,
.order-table td {
  padding: 0.5rem 0.75rem;
  border-block-end: 1px solid #e5e7eb;
  text-align: start;
}
CSS
cat > orders.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Orders</title>
  <link rel="stylesheet" href="static/css/admin.css">
</head>
<body>
  <table class="order-table">
    <thead><tr><th>Order</th><th>Status</th></tr></thead>
    <tbody>
      <tr><td>#1042</td><td><span class="status-badge status-badge--paid">Paid</span></td></tr>
      <tr><td>#1043</td><td><span class="status-badge status-badge--refunded">Refunded</span></td></tr>
    </tbody>
  </table>
</body>
</html>
HTML
git add -A
git commit -qm "Admin orders table"
cat >> static/css/admin.css <<'CSS'

.status-badge {
  display: inline-block;
  padding: 0.125rem 0.5rem;
  border-radius: 999px;
  font-size: 0.8125rem;
  font-weight: 600;
  line-height: 1.5;
}

.status-badge--paid {
  color: #14532d;
  background: #dcfce7;
}

.status-badge--refunded {
  color: #7c2d12;
  background: #ffedd5;
}
CSS
