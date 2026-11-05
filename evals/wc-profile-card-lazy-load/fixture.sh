#!/bin/bash
# A profile page that passes a user object to a custom element, plus an
# uncommitted change that loads the element's definition lazily.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components api
cat > src/components/profile-card.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: block; padding: 1rem; border: 1px solid #d1d5db; border-radius: 8px; }
    img { inline-size: 64px; block-size: 64px; border-radius: 50%; }
  </style>
  <img alt="">
  <h2></h2>
  <p></p>
`;

export class ProfileCard extends HTMLElement {
  #user = null;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  get user() {
    return this.#user;
  }

  set user(value) {
    this.#user = value;
    this.#render();
  }

  #render() {
    const root = this.shadowRoot;
    root.querySelector('img').src = this.#user?.avatarUrl ?? '';
    root.querySelector('h2').textContent = this.#user?.name ?? '';
    root.querySelector('p').textContent = this.#user?.role ?? '';
  }
}

customElements.define('profile-card', ProfileCard);
JS
cat > src/main.js <<'JS'
import './components/profile-card.js';

const response = await fetch('api/me.json');
document.querySelector('profile-card').user = await response.json();
JS
printf '{"name":"Sam Rivera","role":"Support lead","avatarUrl":"/avatars/sam.png"}\n' > api/me.json
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Your profile</title>
  <script type="module" src="src/main.js"></script>
</head>
<body>
  <h1>Your profile</h1>
  <profile-card></profile-card>
</body>
</html>
HTML
git add -A
git commit -qm "Profile page"
cat > src/main.js <<'JS'
// profile-card is below the fold on most screens, so load it after the data.
const response = await fetch('api/me.json');
const card = document.querySelector('profile-card');
card.user = await response.json();

import('./components/profile-card.js');
JS
