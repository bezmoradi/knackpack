#!/bin/bash
# A marketing site that enhances server-rendered markup with light-DOM custom
# elements by design, plus an uncommitted, correct site-nav element.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/elements styles
cat > README.md <<'MD'
# Marketing site

Pages are rendered on the server. Custom elements in `src/elements/` only
enhance the markup already inside them: they don't use shadow DOM, so the
global stylesheet and our utility classes keep styling everything, and the
page works before (and without) JavaScript.
MD
cat > styles/site.css <<'CSS'
.nav-list { display: flex; gap: 1rem; list-style: none; margin: 0; padding: 0; }
.nav-toggle { display: none; }
@media (max-width: 40rem) {
  .nav-toggle { display: inline-flex; }
  site-nav:defined .nav-list { display: none; }
  site-nav:defined .nav-toggle[aria-expanded="true"] + .nav-list { display: grid; }
}
CSS
cat > src/elements/copy-year.js <<'JS'
// Replaces the server-rendered year with the visitor's current year.
class CopyYear extends HTMLElement {
  connectedCallback() {
    this.textContent = String(new Date().getFullYear());
  }
}
customElements.define('copy-year', CopyYear);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Acme Trail</title>
  <link rel="stylesheet" href="styles/site.css">
  <script type="module" src="src/elements/copy-year.js"></script>
</head>
<body>
  <header>
    <nav aria-label="Main">
      <ul class="nav-list">
        <li><a href="/features">Features</a></li>
        <li><a href="/pricing">Pricing</a></li>
        <li><a href="/blog">Blog</a></li>
      </ul>
    </nav>
  </header>
  <main><h1>Plan your next trail run</h1></main>
  <footer>&copy; <copy-year>2026</copy-year></footer>
</body>
</html>
HTML
git add -A
git commit -qm "Marketing site"
cat > src/elements/site-nav.js <<'JS'
// Mobile menu: wires the server-rendered toggle button to the list after it.
// Light DOM by design (see README); the list is visible without JavaScript.
class SiteNav extends HTMLElement {
  #controller = null;

  connectedCallback() {
    const toggle = this.querySelector('.nav-toggle');
    const list = this.querySelector('.nav-list');
    if (!toggle || !list) return;
    this.#controller = new AbortController();
    const { signal } = this.#controller;

    toggle.addEventListener('click', () => {
      this.#setOpen(toggle.getAttribute('aria-expanded') !== 'true');
    }, { signal });

    document.addEventListener('keydown', (event) => {
      if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
        this.#setOpen(false);
        toggle.focus();
      }
    }, { signal });
  }

  disconnectedCallback() {
    this.#controller?.abort();
    this.#controller = null;
  }

  #setOpen(open) {
    this.querySelector('.nav-toggle').setAttribute('aria-expanded', String(open));
  }
}

customElements.define('site-nav', SiteNav);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Acme Trail</title>
  <link rel="stylesheet" href="styles/site.css">
  <script type="module" src="src/elements/copy-year.js"></script>
  <script type="module" src="src/elements/site-nav.js"></script>
</head>
<body>
  <header>
    <site-nav>
      <nav aria-label="Main">
        <button type="button" class="nav-toggle" aria-expanded="false" aria-controls="main-nav-list">Menu</button>
        <ul class="nav-list" id="main-nav-list">
          <li><a href="/features">Features</a></li>
          <li><a href="/pricing">Pricing</a></li>
          <li><a href="/blog">Blog</a></li>
        </ul>
      </nav>
    </site-nav>
  </header>
  <main><h1>Plan your next trail run</h1></main>
  <footer>&copy; <copy-year>2026</copy-year></footer>
</body>
</html>
HTML
