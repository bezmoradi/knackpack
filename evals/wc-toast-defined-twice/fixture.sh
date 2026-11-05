#!/bin/bash
# A storefront that registers its own toast element, plus an uncommitted
# vendored chat widget that ships and registers a second copy of it.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components widgets/support-chat/vendor
cat > src/components/app-toast.js <<'JS'
// Toast notifications, v1.4. Usage: document.querySelector('app-toast').show('Saved');
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { position: fixed; inset-block-end: 1rem; inset-inline-end: 1rem; }
    [part="message"] { padding: 0.75rem 1rem; border-radius: 6px; background: #111827; color: #fff; }
    [hidden] { display: none; }
  </style>
  <div part="message" role="status" hidden></div>
`;

export class AppToast extends HTMLElement {
  #message;
  #timer = 0;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
    this.#message = this.shadowRoot.querySelector('[part="message"]');
  }

  disconnectedCallback() {
    clearTimeout(this.#timer);
  }

  show(text, ms = 4000) {
    this.#message.textContent = text;
    this.#message.hidden = false;
    clearTimeout(this.#timer);
    this.#timer = setTimeout(() => { this.#message.hidden = true; }, ms);
  }
}

customElements.define('app-toast', AppToast);
JS
cat > src/main.js <<'JS'
import './components/app-toast.js';

document.querySelector('#add-to-cart').addEventListener('click', () => {
  document.querySelector('app-toast').show('Added to cart');
});
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Storefront</title>
  <script type="module" src="src/main.js"></script>
</head>
<body>
  <main>
    <h1>Trail runner shoes</h1>
    <button id="add-to-cart" type="button">Add to cart</button>
  </main>
  <app-toast></app-toast>
</body>
</html>
HTML
git add -A
git commit -qm "Storefront page with toast notifications"
cat > widgets/support-chat/vendor/app-toast.js <<'JS'
// Toast notifications, v1.2 (bundled with support-chat).
export class AppToast extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).innerHTML = '<div part="message" role="status"></div>';
  }

  show(text) {
    this.shadowRoot.querySelector('[part="message"]').textContent = text;
  }
}

customElements.define('app-toast', AppToast);
JS
cat > widgets/support-chat/chat.js <<'JS'
// Support chat launcher, from the support team's widget build.
import './vendor/app-toast.js';

class SupportChat extends HTMLElement {
  connectedCallback() {
    this.innerHTML = '<button type="button">Chat with support</button>';
    this.querySelector('button').addEventListener('click', () => {
      window.open('https://support.example.com/chat', 'support-chat', 'width=420,height=640');
    });
  }
}

customElements.define('support-chat', SupportChat);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Storefront</title>
  <script type="module" src="src/main.js"></script>
  <script type="module" src="widgets/support-chat/chat.js"></script>
</head>
<body>
  <main>
    <h1>Trail runner shoes</h1>
    <button id="add-to-cart" type="button">Add to cart</button>
  </main>
  <app-toast></app-toast>
  <support-chat></support-chat>
</body>
</html>
HTML
