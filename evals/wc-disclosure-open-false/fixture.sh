#!/bin/bash
# A help center page, plus an uncommitted disclosure element whose boolean
# property writes the string "false" into its attribute.
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
  <title>Help center</title>
</head>
<body>
  <h1>Frequently asked questions</h1>
  <h2>How do I reset my password?</h2>
  <p>Use the "Forgot password" link on the sign-in page.</p>
</body>
</html>
HTML
git add -A
git commit -qm "Help center page"
cat > src/components/info-disclosure.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: block; border-block-end: 1px solid #e5e7eb; }
    .panel { display: none; padding-block: 0.5rem; }
    :host([open]) .panel { display: block; }
  </style>
  <button type="button" class="toggle" aria-expanded="false"><slot name="summary"></slot></button>
  <div class="panel">
    <slot></slot>
    <button type="button" class="close">Close</button>
  </div>
`;

class InfoDisclosure extends HTMLElement {
  static observedAttributes = ['open'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
    this.shadowRoot.querySelector('.toggle').addEventListener('click', () => { this.open = !this.open; });
    this.shadowRoot.querySelector('.close').addEventListener('click', () => { this.open = false; });
  }

  get open() {
    return this.hasAttribute('open');
  }

  set open(value) {
    this.setAttribute('open', value);
  }

  attributeChangedCallback() {
    this.shadowRoot.querySelector('.toggle').setAttribute('aria-expanded', String(this.open));
  }
}

customElements.define('info-disclosure', InfoDisclosure);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Help center</title>
  <script type="module" src="src/components/info-disclosure.js"></script>
</head>
<body>
  <h1>Frequently asked questions</h1>
  <info-disclosure>
    <span slot="summary">How do I reset my password?</span>
    <p>Use the "Forgot password" link on the sign-in page.</p>
  </info-disclosure>
  <info-disclosure>
    <span slot="summary">Can I change my username?</span>
    <p>Yes, once every 30 days, from your profile settings.</p>
  </info-disclosure>
</body>
</html>
HTML
