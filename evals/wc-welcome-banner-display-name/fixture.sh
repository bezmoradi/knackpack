#!/bin/bash
# A team dashboard that greets the signed-in user, plus an uncommitted
# welcome-banner element that renders the display name with innerHTML.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components api docs
cat > docs/profile.md <<'MD'
# Profiles

Members choose their own display name on the profile page (up to 64
characters). Admins see every member's display name in the member list.
MD
cat > api/me.json <<'JSON'
{"id": 41, "displayName": "Sam Rivera", "workspace": "Field team"}
JSON
cat > src/main.js <<'JS'
const me = await (await fetch('api/me.json')).json();
document.querySelector('#workspace').textContent = me.workspace;
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Dashboard</title>
  <script type="module" src="src/main.js"></script>
</head>
<body>
  <header><span id="workspace"></span></header>
  <main><h1>Dashboard</h1></main>
</body>
</html>
HTML
git add -A
git commit -qm "Dashboard shell"
cat > src/components/welcome-banner.js <<'JS'
class WelcomeBanner extends HTMLElement {
  static observedAttributes = ['name'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  attributeChangedCallback() {
    this.#render();
  }

  connectedCallback() {
    this.#render();
  }

  #render() {
    const name = this.getAttribute('name') ?? 'there';
    this.shadowRoot.innerHTML = `
      <style>
        :host { display: block; padding: 1rem; background: #eef2ff; border-radius: 8px; }
      </style>
      <h2>Welcome back, ${name}!</h2>
      <p>Here's what changed since your last visit.</p>
    `;
  }
}

customElements.define('welcome-banner', WelcomeBanner);
JS
cat > src/main.js <<'JS'
import './components/welcome-banner.js';

const me = await (await fetch('api/me.json')).json();
document.querySelector('#workspace').textContent = me.workspace;
document.querySelector('welcome-banner').setAttribute('name', me.displayName);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Dashboard</title>
  <script type="module" src="src/main.js"></script>
</head>
<body>
  <header><span id="workspace"></span></header>
  <main>
    <h1>Dashboard</h1>
    <welcome-banner></welcome-banner>
  </main>
</body>
</html>
HTML
