#!/bin/bash
# An admin single-page app that replaces its view on navigation, plus an
# uncommitted command palette that listens on document for Ctrl+K.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components
cat > src/router.js <<'JS'
// Each navigation builds a fresh view and replaces the old one.
const views = {
  orders: () => '<h1>Orders</h1><command-palette></command-palette>',
  customers: () => '<h1>Customers</h1><command-palette></command-palette>',
  invoices: () => '<h1>Invoices</h1><command-palette></command-palette>',
};

export function navigate(name) {
  const view = document.createElement('section');
  view.innerHTML = views[name]();
  document.querySelector('#view').replaceChildren(view);
}

document.querySelector('nav').addEventListener('click', (event) => {
  const name = event.target.dataset.view;
  if (name) navigate(name);
});
JS
cat > src/main.js <<'JS'
import { navigate } from './router.js';

navigate('orders');
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Admin</title>
  <script type="module" src="src/main.js"></script>
</head>
<body>
  <nav>
    <button type="button" data-view="orders">Orders</button>
    <button type="button" data-view="customers">Customers</button>
    <button type="button" data-view="invoices">Invoices</button>
  </nav>
  <main id="view"></main>
</body>
</html>
HTML
git add -A
git commit -qm "Admin views"
cat > src/components/command-palette.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    dialog { inline-size: min(36rem, 90vw); }
    li { padding: 0.25rem 0; }
  </style>
  <dialog>
    <input type="search" aria-label="Search commands">
    <ul></ul>
  </dialog>
`;

class CommandPalette extends HTMLElement {
  #commands = [];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  connectedCallback() {
    document.addEventListener('keydown', (event) => {
      if ((event.ctrlKey || event.metaKey) && event.key === 'k') {
        event.preventDefault();
        this.open();
      }
    });
  }

  async open() {
    const response = await fetch('/api/commands');
    this.#commands = await response.json();
    const list = this.shadowRoot.querySelector('ul');
    list.replaceChildren(...this.#commands.map((command) => {
      const item = document.createElement('li');
      item.textContent = command.label;
      return item;
    }));
    this.shadowRoot.querySelector('dialog').showModal();
  }
}

customElements.define('command-palette', CommandPalette);
JS
cat > src/main.js <<'JS'
import './components/command-palette.js';
import { navigate } from './router.js';

navigate('orders');
JS
mkdir -p api
printf '[{"label":"New order"},{"label":"Find customer"},{"label":"Export invoices"}]\n' > api/commands
