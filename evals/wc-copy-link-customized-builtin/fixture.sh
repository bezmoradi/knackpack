#!/bin/bash
# A docs site that supports Safari, plus an uncommitted copy button written
# as a customized built-in element.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src docs
cat > package.json <<'JSON'
{
  "name": "docs-site",
  "private": true,
  "type": "module",
  "browserslist": ["last 2 Chrome versions", "last 2 Firefox versions", "Firefox ESR", "Safari >= 17", "iOS >= 17"]
}
JSON
cat > docs/getting-started.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Getting started</title>
</head>
<body>
  <h1>Getting started</h1>
  <pre><code id="install">npm install @acme/sdk</code></pre>
  <pre><code id="init">acme init --region eu-west-1</code></pre>
</body>
</html>
HTML
git add -A
git commit -qm "Getting started page"
cat > src/copy-link.js <<'JS'
// <button is="copy-link" data-target="install">Copy</button>
class CopyLink extends HTMLButtonElement {
  connectedCallback() {
    this.type = 'button';
    this.addEventListener('click', this.#copy);
  }

  disconnectedCallback() {
    this.removeEventListener('click', this.#copy);
  }

  #copy = async () => {
    const target = document.getElementById(this.dataset.target);
    await navigator.clipboard.writeText(target.textContent);
    this.textContent = 'Copied';
    setTimeout(() => { this.textContent = 'Copy'; }, 1500);
  };
}

customElements.define('copy-link', CopyLink, { extends: 'button' });
JS
cat > docs/getting-started.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Getting started</title>
  <script type="module" src="../src/copy-link.js"></script>
</head>
<body>
  <h1>Getting started</h1>
  <pre><code id="install">npm install @acme/sdk</code></pre>
  <button is="copy-link" data-target="install">Copy</button>
  <pre><code id="init">acme init --region eu-west-1</code></pre>
  <button is="copy-link" data-target="init">Copy</button>
</body>
</html>
HTML
