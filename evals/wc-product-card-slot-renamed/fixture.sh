#!/bin/bash
# A shop whose pages fill product-card's named slot, plus an uncommitted
# rename of that slot inside the component only.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components pages docs
cat > src/components/product-card.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: grid; gap: 0.5rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; }
    ::slotted([slot="heading"]) { margin: 0; font-size: 1.125rem; }
    .price { font-weight: 700; }
  </style>
  <slot name="media"></slot>
  <slot name="heading"></slot>
  <slot></slot>
  <span class="price" part="price"></span>
`;

class ProductCard extends HTMLElement {
  static observedAttributes = ['price'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  attributeChangedCallback(name, oldValue, newValue) {
    this.shadowRoot.querySelector('.price').textContent = newValue ?? '';
  }
}

customElements.define('product-card', ProductCard);
JS
for page in shoes jackets packs; do
cat > pages/$page.html <<HTML
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${page}</title>
  <script type="module" src="../src/components/product-card.js"></script>
</head>
<body>
  <h1>${page}</h1>
  <product-card price="\$129.00">
    <img slot="media" src="/img/${page}-1.jpg" alt="">
    <h2 slot="heading">Trail ${page} one</h2>
    <p>Our most popular ${page}.</p>
  </product-card>
  <product-card price="\$89.00">
    <img slot="media" src="/img/${page}-2.jpg" alt="">
    <h2 slot="heading">Trail ${page} two</h2>
    <p>Lighter and cheaper.</p>
  </product-card>
</body>
</html>
HTML
done
cat > docs/naming.md <<'MD'
# Naming guide

- Slots are named for their role: `media`, `title`, `actions`.
MD
git add -A
git commit -qm "Product pages with product-card"
cat > src/components/product-card.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: grid; gap: 0.5rem; padding: 1rem; border: 1px solid #e5e7eb; border-radius: 8px; }
    ::slotted([slot="title"]) { margin: 0; font-size: 1.125rem; line-height: 1.3; }
    .price { font-weight: 700; }
  </style>
  <slot name="media"></slot>
  <slot name="title"></slot>
  <slot></slot>
  <span class="price" part="price"></span>
`;

class ProductCard extends HTMLElement {
  static observedAttributes = ['price'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  attributeChangedCallback(name, oldValue, newValue) {
    this.shadowRoot.querySelector('.price').textContent = newValue ?? '';
  }
}

customElements.define('product-card', ProductCard);
JS
