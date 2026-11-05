#!/bin/bash
# A checkout page with third-party scripts, plus an uncommitted card-fields
# element that relies on a closed shadow root to hide card data from them.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Checkout</title>
  <script src="https://cdn.analytics.example/tag.js" async></script>
  <script src="https://widget.chat.example/loader.js" async></script>
  <script type="module" src="src/checkout.js"></script>
</head>
<body>
  <form id="pay">
    <label>Card number <input name="number" inputmode="numeric" autocomplete="cc-number"></label>
    <label>CVC <input name="cvc" inputmode="numeric" autocomplete="cc-csc"></label>
    <button>Pay</button>
  </form>
</body>
</html>
HTML
cat > src/checkout.js <<'JS'
document.querySelector('#pay').addEventListener('submit', async (event) => {
  event.preventDefault();
  const data = new FormData(event.currentTarget);
  await fetch('/api/pay', { method: 'POST', body: data });
});
JS
git add -A
git commit -qm "Checkout form"
cat > src/components/card-fields.js <<'JS'
// Card inputs live in a CLOSED shadow root: the analytics and chat scripts on
// this page can't query into it, so they can never see card numbers.
const template = document.createElement('template');
template.innerHTML = `
  <label>Card number <input name="number" inputmode="numeric" autocomplete="cc-number"></label>
  <label>CVC <input name="cvc" inputmode="numeric" autocomplete="cc-csc"></label>
`;

class CardFields extends HTMLElement {
  #root;

  constructor() {
    super();
    this.#root = this.attachShadow({ mode: 'closed' });
    this.#root.append(template.content.cloneNode(true));
  }

  // Only checkout.js calls this, right before submitting to our API.
  getCardData() {
    return {
      number: this.#root.querySelector('[name="number"]').value,
      cvc: this.#root.querySelector('[name="cvc"]').value,
    };
  }
}

customElements.define('card-fields', CardFields);
JS
cat > src/checkout.js <<'JS'
import './components/card-fields.js';

document.querySelector('#pay').addEventListener('submit', async (event) => {
  event.preventDefault();
  const card = document.querySelector('card-fields').getCardData();
  await fetch('/api/pay', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(card),
  });
});
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Checkout</title>
  <script src="https://cdn.analytics.example/tag.js" async></script>
  <script src="https://widget.chat.example/loader.js" async></script>
  <script type="module" src="src/checkout.js"></script>
</head>
<body>
  <form id="pay">
    <card-fields></card-fields>
    <button>Pay</button>
  </form>
</body>
</html>
HTML
