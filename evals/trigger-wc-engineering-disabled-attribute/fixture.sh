#!/bin/bash
# A small component library with one custom element, <copy-button>, which
# copies its value attribute to the clipboard. The user asks for a new
# attribute, which is Web Components engineering, not a review.
set -euo pipefail
git init -q -b main
git config user.name "Lena Fischer"
git config user.email "lena@example.com"
mkdir -p src demo
cat > package.json <<'JSON'
{ "name": "@acme/copy-button", "version": "1.2.0", "type": "module", "exports": "./src/copy-button.js" }
JSON
cat > src/copy-button.js <<'JS'
const template = document.createElement("template");
template.innerHTML = `
  <style>
    :host { display: inline-block; }
    button { font: inherit; padding: 0.25rem 0.75rem; border-radius: 4px; border: 1px solid #888; background: #fff; cursor: pointer; }
  </style>
  <button type="button" part="button"><slot>Copy</slot></button>
`;

export class CopyButton extends HTMLElement {
  static observedAttributes = ["value"];

  constructor() {
    super();
    this.attachShadow({ mode: "open" }).append(template.content.cloneNode(true));
    this._button = this.shadowRoot.querySelector("button");
    this._onClick = this._onClick.bind(this);
  }

  connectedCallback() {
    this._button.addEventListener("click", this._onClick);
  }

  disconnectedCallback() {
    this._button.removeEventListener("click", this._onClick);
  }

  get value() {
    return this.getAttribute("value") ?? "";
  }

  set value(v) {
    this.setAttribute("value", v);
  }

  async _onClick() {
    await navigator.clipboard.writeText(this.value);
    this.dispatchEvent(new CustomEvent("copied", { bubbles: true, composed: true, detail: { value: this.value } }));
  }
}

if (!customElements.get("copy-button")) customElements.define("copy-button", CopyButton);
JS
cat > demo/index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>copy-button demo</title><script type="module" src="../src/copy-button.js"></script></head>
<body><p>API key: <code>pk_demo_123</code> <copy-button value="pk_demo_123">Copy key</copy-button></p></body>
</html>
HTML
cat > README.md <<'MD2'
# @acme/copy-button

`<copy-button value="text">Label</copy-button>` copies `value` to the clipboard and fires a `copied` event.
MD2
git add -A
git commit -qm "copy-button element"
