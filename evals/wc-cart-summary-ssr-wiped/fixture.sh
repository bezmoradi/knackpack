#!/bin/bash
# A server-rendered page with a declarative shadow root, plus an uncommitted
# client definition that re-creates the shadow root and fetches before rendering.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p server/templates src/components api
cat > server/templates/cart-summary.html <<'HTML'
<cart-summary>
  <template shadowrootmode="open">
    <style>
      :host { display: flex; gap: 1rem; align-items: center; }
      a { font-weight: 600; }
    </style>
    <span class="count">{{ cart.count }} items</span>
    <span class="total">{{ cart.total }}</span>
    <a href="/checkout">Checkout</a>
  </template>
</cart-summary>
HTML
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Shop</title>
</head>
<body>
  <header>
    <!-- rendered from server/templates/cart-summary.html -->
    <cart-summary>
      <template shadowrootmode="open">
        <style>
          :host { display: flex; gap: 1rem; align-items: center; }
          a { font-weight: 600; }
        </style>
        <span class="count">3 items</span>
        <span class="total">$42.00</span>
        <a href="/checkout">Checkout</a>
      </template>
    </cart-summary>
  </header>
  <main><h1>Shop</h1></main>
</body>
</html>
HTML
git add -A
git commit -qm "Server-rendered cart summary"
cat > src/components/cart-summary.js <<'JS'
class CartSummary extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  async connectedCallback() {
    const response = await fetch('/api/cart');
    const cart = await response.json();
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: flex; gap: 1rem; align-items: center; }
        a { font-weight: 600; }
      </style>
      <span class="count">${cart.count} items</span>
      <span class="total">${cart.total}</span>
      <a href="/checkout">Checkout</a>
    `;
  }
}

customElements.define('cart-summary', CartSummary);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Shop</title>
  <script type="module" src="src/components/cart-summary.js"></script>
</head>
<body>
  <header>
    <!-- rendered from server/templates/cart-summary.html -->
    <cart-summary>
      <template shadowrootmode="open">
        <style>
          :host { display: flex; gap: 1rem; align-items: center; }
          a { font-weight: 600; }
        </style>
        <span class="count">3 items</span>
        <span class="total">$42.00</span>
        <a href="/checkout">Checkout</a>
      </template>
    </cart-summary>
  </header>
  <main><h1>Shop</h1></main>
</body>
</html>
HTML
