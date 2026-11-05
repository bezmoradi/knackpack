#!/bin/bash
# A site header whose search box moves into a custom element with a shadow
# root, labelled by an element in the page.
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
  <title>Outdoor gear</title>
</head>
<body>
  <header>
    <form role="search" action="/search">
      <span id="site-search-label">Search products</span>
      <input type="search" name="q" aria-labelledby="site-search-label">
      <button>Search</button>
    </form>
  </header>
  <main><h1>Outdoor gear</h1></main>
</body>
</html>
HTML
git add -A
git commit -qm "Header with product search"
cat > src/components/search-field.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: inline-flex; gap: 0.5rem; }
    input { padding: 0.375rem 0.5rem; }
  </style>
  <input type="search" name="q" autocomplete="off">
  <button type="submit">Search</button>
`;

class SearchField extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  connectedCallback() {
    const input = this.shadowRoot.querySelector('input');
    const labelledBy = this.getAttribute('aria-labelledby');
    if (labelledBy) input.setAttribute('aria-labelledby', labelledBy);
    input.addEventListener('keydown', (event) => {
      if (event.key === 'Enter') this.closest('form')?.requestSubmit();
    });
  }
}

customElements.define('search-field', SearchField);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Outdoor gear</title>
  <script type="module" src="src/components/search-field.js"></script>
</head>
<body>
  <header>
    <form role="search" action="/search">
      <span id="site-search-label">Search products</span>
      <search-field aria-labelledby="site-search-label"></search-field>
    </form>
  </header>
  <main><h1>Outdoor gear</h1></main>
</body>
</html>
HTML
