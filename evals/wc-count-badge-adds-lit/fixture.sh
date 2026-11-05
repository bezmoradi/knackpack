#!/bin/bash
# A dependency-free published component package, plus an uncommitted badge
# written with Lit.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "@acme-ui/elements",
  "version": "2.3.0",
  "description": "Framework-free custom elements for our product surfaces.",
  "type": "module",
  "exports": {
    "./status-dot.js": "./src/status-dot.js",
    "./kbd-key.js": "./src/kbd-key.js"
  },
  "files": ["src"],
  "sideEffects": ["./src/*.js"]
}
JSON
cat > README.md <<'MD'
# @acme-ui/elements

Small custom elements that work in any framework or none.

- No runtime dependencies: each element is a plain `HTMLElement` subclass, so
  consumers never get a second copy of a rendering library.
- Import an element's module to register it, e.g. `import '@acme-ui/elements/status-dot.js'`.
MD
cat > src/status-dot.js <<'JS'
const sheet = new CSSStyleSheet();
sheet.replaceSync(`
  :host { display: inline-block; inline-size: 0.5rem; block-size: 0.5rem; border-radius: 50%; background: #9ca3af; }
  :host([state="ok"]) { background: #15803d; }
  :host([state="error"]) { background: #b91c1c; }
`);

export class StatusDot extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).adoptedStyleSheets = [sheet];
  }
}

if (!customElements.get('status-dot')) customElements.define('status-dot', StatusDot);
JS
cat > src/kbd-key.js <<'JS'
const sheet = new CSSStyleSheet();
sheet.replaceSync(':host { font-family: ui-monospace, monospace; padding: 0 0.25rem; border: 1px solid #d1d5db; border-radius: 4px; }');

export class KbdKey extends HTMLElement {
  constructor() {
    super();
    const root = this.attachShadow({ mode: 'open' });
    root.adoptedStyleSheets = [sheet];
    root.append(document.createElement('slot'));
  }
}

if (!customElements.get('kbd-key')) customElements.define('kbd-key', KbdKey);
JS
git add -A
git commit -qm "Release 2.3.0"
cat > src/count-badge.js <<'JS'
import { LitElement, css, html } from 'lit';

export class CountBadge extends LitElement {
  static properties = { count: { type: Number } };

  static styles = css`
    :host { display: inline-block; min-inline-size: 1.25rem; padding: 0 0.375rem; border-radius: 999px; background: #1d4ed8; color: #fff; font-size: 0.75rem; text-align: center; }
  `;

  constructor() {
    super();
    this.count = 0;
  }

  render() {
    return html`${this.count > 99 ? '99+' : this.count}`;
  }
}

if (!customElements.get('count-badge')) customElements.define('count-badge', CountBadge);
JS
cat > package.json <<'JSON'
{
  "name": "@acme-ui/elements",
  "version": "2.4.0",
  "description": "Framework-free custom elements for our product surfaces.",
  "type": "module",
  "exports": {
    "./status-dot.js": "./src/status-dot.js",
    "./kbd-key.js": "./src/kbd-key.js",
    "./count-badge.js": "./src/count-badge.js"
  },
  "files": ["src"],
  "sideEffects": ["./src/*.js"],
  "dependencies": {
    "lit": "^3.3.0"
  }
}
JSON
