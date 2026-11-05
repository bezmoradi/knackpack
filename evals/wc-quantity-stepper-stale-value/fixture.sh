#!/bin/bash
# An order form, plus an uncommitted form-associated quantity stepper that
# replaces its number input.
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
  <title>Order</title>
</head>
<body>
  <form id="order" action="/cart" method="post">
    <input type="hidden" name="sku" value="TR-204">
    <label for="qty">Quantity</label>
    <input id="qty" type="number" name="quantity" value="1" min="1" max="10">
    <button>Add to cart</button>
  </form>
</body>
</html>
HTML
git add -A
git commit -qm "Order form"
cat > src/components/quantity-stepper.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: inline-flex; align-items: center; gap: 0.25rem; }
    output { min-inline-size: 2ch; text-align: center; }
  </style>
  <button type="button" data-step="-1" aria-label="Decrease quantity">−</button>
  <output aria-live="polite"></output>
  <button type="button" data-step="1" aria-label="Increase quantity">+</button>
`;

class QuantityStepper extends HTMLElement {
  static formAssociated = true;
  #internals;
  #value = 1;

  constructor() {
    super();
    this.#internals = this.attachInternals();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
    this.shadowRoot.addEventListener('click', (event) => {
      const step = Number(event.target.dataset.step);
      if (step) this.value = this.#value + step;
    });
  }

  connectedCallback() {
    this.#value = Number(this.getAttribute('value') ?? 1);
    this.#render();
    this.#internals.setFormValue(String(this.#value));
  }

  get value() {
    return this.#value;
  }

  set value(next) {
    const min = Number(this.getAttribute('min') ?? 1);
    const max = Number(this.getAttribute('max') ?? 99);
    this.#value = Math.min(max, Math.max(min, next));
    this.#render();
    this.dispatchEvent(new Event('change', { bubbles: true }));
  }

  #render() {
    this.shadowRoot.querySelector('output').textContent = String(this.#value);
  }
}

customElements.define('quantity-stepper', QuantityStepper);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Order</title>
  <script type="module" src="src/components/quantity-stepper.js"></script>
</head>
<body>
  <form id="order" action="/cart" method="post">
    <input type="hidden" name="sku" value="TR-204">
    <span id="qty-label">Quantity</span>
    <quantity-stepper name="quantity" value="1" min="1" max="10" role="group" aria-labelledby="qty-label"></quantity-stepper>
    <button>Add to cart</button>
  </form>
</body>
</html>
HTML
