#!/bin/bash
# The same kind of <copy-button> element, committed; the uncommitted change
# renames its event and stops it crossing the shadow boundary. The case is
# about which component starts for a review of a custom element.
set -euo pipefail
git init -q -b main
git config user.name "Lena Fischer"
git config user.email "lena@example.com"
mkdir -p src
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
git add -A
git commit -qm "copy-button element"
sed -i.bak 's/new CustomEvent("copied", { bubbles: true, composed: true, detail: { value: this.value } })/new CustomEvent("copy-button:copied", { detail: this.value })/' src/copy-button.js
rm src/copy-button.js.bak
grep -q 'copy-button:copied' src/copy-button.js
