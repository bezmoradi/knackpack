#!/bin/bash
# A component library built on two base classes, plus an uncommitted third
# base class and a copy-button built on it.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/base src/components
cat > src/base/base-element.js <<'JS'
// Renders into an open shadow root on connect; subclasses implement render().
export class BaseElement extends HTMLElement {
  static styles = [];

  connectedCallback() {
    if (!this.shadowRoot) {
      this.attachShadow({ mode: 'open' }).adoptedStyleSheets = this.constructor.styles;
    }
    this.render();
  }

  render() {}
}
JS
cat > src/base/themed-element.js <<'JS'
import { BaseElement } from './base-element.js';

const listeners = new Set();
export function setTheme(theme) {
  document.documentElement.dataset.theme = theme;
  for (const listener of listeners) listener(theme);
}

// Re-renders when the theme changes.
export class ThemedElement extends BaseElement {
  #onTheme = () => this.render();

  connectedCallback() {
    listeners.add(this.#onTheme);
    super.connectedCallback();
  }

  disconnectedCallback() {
    listeners.delete(this.#onTheme);
  }
}
JS
cat > src/components/status-pill.js <<'JS'
import { ThemedElement } from '../base/themed-element.js';

const sheet = new CSSStyleSheet();
sheet.replaceSync(':host { display: inline-block; padding: 0 0.5rem; border-radius: 999px; background: var(--pill-bg, #e5e7eb); }');

class StatusPill extends ThemedElement {
  static styles = [sheet];

  render() {
    this.shadowRoot.innerHTML = '<slot></slot>';
  }
}

customElements.define('status-pill', StatusPill);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Components</title>
  <script type="module" src="src/components/status-pill.js"></script>
</head>
<body>
  <status-pill>Active</status-pill>
</body>
</html>
HTML
git add -A
git commit -qm "Base classes and status-pill"
cat > src/base/focusable-element.js <<'JS'
import { ThemedElement } from './themed-element.js';

// Makes the host keyboard-focusable unless the author set a tabindex.
export class FocusableElement extends ThemedElement {
  connectedCallback() {
    if (!this.hasAttribute('tabindex')) this.setAttribute('tabindex', '0');
  }
}
JS
cat > src/components/copy-button.js <<'JS'
import { FocusableElement } from '../base/focusable-element.js';

const sheet = new CSSStyleSheet();
sheet.replaceSync(':host { display: inline-flex; cursor: pointer; padding: 0.25rem 0.5rem; border: 1px solid; border-radius: 4px; }');

class CopyButton extends FocusableElement {
  static styles = [sheet];

  constructor() {
    super();
    this.addEventListener('click', () => this.#copy());
    this.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        this.#copy();
      }
    });
  }

  render() {
    this.setAttribute('role', 'button');
    this.shadowRoot.innerHTML = '<slot>Copy</slot>';
  }

  async #copy() {
    await navigator.clipboard.writeText(this.getAttribute('value') ?? '');
    this.dispatchEvent(new CustomEvent('copied', { bubbles: true }));
  }
}

customElements.define('copy-button', CopyButton);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Components</title>
  <script type="module" src="src/components/status-pill.js"></script>
  <script type="module" src="src/components/copy-button.js"></script>
</head>
<body>
  <status-pill>Active</status-pill>
  <p>API key: <code>pk_live_example</code> <copy-button value="pk_live_example">Copy key</copy-button></p>
</body>
</html>
HTML
