#!/bin/bash
# A notification settings form, plus an uncommitted form-associated
# toggle-switch element that behaves like a native checkbox.
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
  <title>Notification settings</title>
</head>
<body>
  <form id="settings" action="/settings/notifications" method="post">
    <label><input type="checkbox" name="email-alerts" checked> Email alerts</label>
    <label><input type="checkbox" name="weekly-digest"> Weekly digest</label>
    <button>Save</button>
    <button type="reset">Undo changes</button>
  </form>
</body>
</html>
HTML
git add -A
git commit -qm "Notification settings form"
cat > src/components/toggle-switch.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host {
      display: inline-block;
      position: relative;
      inline-size: 2.75rem;
      block-size: 1.5rem;
      border-radius: 999px;
      background: #4b5563;
      cursor: pointer;
      vertical-align: middle;
    }
    :host([checked]) { background: #1d4ed8; }
    :host(:focus-visible) { outline: 2px solid #1d4ed8; outline-offset: 2px; }
    :host(:disabled) { opacity: 0.5; cursor: not-allowed; }
    .thumb {
      position: absolute;
      inset-block-start: 0.1875rem;
      inset-inline-start: 0.1875rem;
      inline-size: 1.125rem;
      block-size: 1.125rem;
      border-radius: 50%;
      background: #ffffff;
    }
    :host([checked]) .thumb { transform: translateX(1.25rem); }
    :host([checked]:dir(rtl)) .thumb { transform: translateX(-1.25rem); }
    @media (prefers-reduced-motion: no-preference) {
      .thumb { transition: transform 150ms ease-out; }
    }
    @media (forced-colors: active) {
      :host { border: 1px solid CanvasText; }
      .thumb { background: CanvasText; }
      :host([checked]) .thumb { background: Highlight; }
    }
  </style>
  <span class="thumb"></span>
`;

// A switch that behaves like a native checkbox in forms: it submits its value
// (default "on") under its name when checked, resets, follows fieldset
// disabling, and restores its state on back/forward navigation.
export class ToggleSwitch extends HTMLElement {
  static formAssociated = true;
  static observedAttributes = ['checked', 'value'];

  #internals;
  #defaultChecked = null;

  constructor() {
    super();
    this.#internals = this.attachInternals();
    this.#internals.role = 'switch';
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
    this.addEventListener('click', () => this.#toggle());
    this.addEventListener('keydown', (event) => {
      if (event.key === ' ' || event.key === 'Enter') {
        event.preventDefault();
        this.#toggle();
      }
    });
  }

  connectedCallback() {
    // A value assigned before the element was defined is an own property that
    // would hide the accessor below; re-apply it through the setter.
    if (Object.hasOwn(this, 'checked')) {
      const value = this.checked;
      delete this.checked;
      this.checked = value;
    }
    if (this.#defaultChecked === null) this.#defaultChecked = this.hasAttribute('checked');
    if (!this.hasAttribute('tabindex')) this.tabIndex = 0;
    this.#sync();
  }

  attributeChangedCallback() {
    this.#sync();
  }

  get checked() {
    return this.hasAttribute('checked');
  }

  set checked(value) {
    this.toggleAttribute('checked', Boolean(value));
  }

  get value() {
    return this.getAttribute('value') ?? 'on';
  }

  set value(value) {
    this.setAttribute('value', String(value));
  }

  get form() {
    return this.#internals.form;
  }

  get name() {
    return this.getAttribute('name');
  }

  formResetCallback() {
    this.checked = this.#defaultChecked ?? false;
  }

  formDisabledCallback(disabled) {
    this.#internals.ariaDisabled = String(disabled);
  }

  formStateRestoreCallback(state) {
    this.checked = state === 'checked';
  }

  #toggle() {
    if (this.matches(':disabled')) return;
    this.checked = !this.checked;
    this.dispatchEvent(new Event('input', { bubbles: true, composed: true }));
    this.dispatchEvent(new Event('change', { bubbles: true }));
  }

  #sync() {
    this.#internals.ariaChecked = String(this.checked);
    this.#internals.setFormValue(this.checked ? this.value : null, this.checked ? 'checked' : 'unchecked');
  }
}

customElements.define('toggle-switch', ToggleSwitch);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Notification settings</title>
  <script type="module" src="src/components/toggle-switch.js"></script>
</head>
<body>
  <form id="settings" action="/settings/notifications" method="post">
    <label><toggle-switch name="email-alerts" checked></toggle-switch> Email alerts</label>
    <label><toggle-switch name="weekly-digest"></toggle-switch> Weekly digest</label>
    <button>Save</button>
    <button type="reset">Undo changes</button>
  </form>
</body>
</html>
HTML
