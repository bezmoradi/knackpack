#!/bin/bash
# A component library with older defects in two committed components, plus an
# uncommitted, correct size attribute for user-avatar.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components
cat > src/components/notice-bar.js <<'JS'
class NoticeBar extends HTMLElement {
  static observedAttributes = ['message'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  attributeChangedCallback() {
    this.shadowRoot.innerHTML = `<p role="status">${this.getAttribute('message') ?? ''}</p>`;
  }
}

customElements.define('notice-bar', NoticeBar);
JS
cat > src/components/menu-button.js <<'JS'
class MenuButton extends HTMLElement {
  connectedCallback() {
    this.querySelector('button').addEventListener('click', () => this.toggleAttribute('open'));
    document.addEventListener('click', (event) => {
      if (!this.contains(event.target)) this.removeAttribute('open');
    });
  }
}

customElements.define('menu-button', MenuButton);
JS
cat > src/components/user-avatar.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: inline-block; inline-size: 40px; block-size: 40px; }
    img { inline-size: 100%; block-size: 100%; border-radius: 50%; object-fit: cover; }
  </style>
  <img alt="">
`;

class UserAvatar extends HTMLElement {
  static observedAttributes = ['src', 'name'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  attributeChangedCallback(name, oldValue, newValue) {
    const img = this.shadowRoot.querySelector('img');
    if (name === 'src') img.src = newValue ?? '';
    if (name === 'name') img.alt = newValue ?? '';
  }
}

customElements.define('user-avatar', UserAvatar);
JS
cat > README.md <<'MD'
# Components

- `<user-avatar src name>`: a round avatar image; `name` becomes its alt text.
- `<notice-bar message>`: a status message.
- `<menu-button>`: wraps a button and a menu; toggles `open`.
MD
git add -A
git commit -qm "Component library"
cat > src/components/user-avatar.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: inline-block; inline-size: var(--avatar-size, 40px); block-size: var(--avatar-size, 40px); }
    :host([size="small"]) { --avatar-size: 24px; }
    :host([size="large"]) { --avatar-size: 64px; }
    img { inline-size: 100%; block-size: 100%; border-radius: 50%; object-fit: cover; }
  </style>
  <img alt="">
`;

const SIZES = ['small', 'medium', 'large'];

class UserAvatar extends HTMLElement {
  static observedAttributes = ['src', 'name'];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  attributeChangedCallback(name, oldValue, newValue) {
    const img = this.shadowRoot.querySelector('img');
    if (name === 'src') img.src = newValue ?? '';
    if (name === 'name') img.alt = newValue ?? '';
  }

  /** One of "small" (24px), "medium" (40px, the default) or "large" (64px). */
  get size() {
    const value = this.getAttribute('size');
    return SIZES.includes(value) ? value : 'medium';
  }

  set size(value) {
    this.setAttribute('size', String(value));
  }
}

customElements.define('user-avatar', UserAvatar);
JS
cat > README.md <<'MD'
# Components

- `<user-avatar src name size>`: a round avatar image; `name` becomes its alt text; `size` is `small` (24px), `medium` (40px, the default) or `large` (64px), also settable as the `size` property.
- `<notice-bar message>`: a status message.
- `<menu-button>`: wraps a button and a menu; toggles `open`.
MD
