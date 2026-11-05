#!/bin/bash
# A docs page whose section header sticks while the page scrolls, plus an
# uncommitted change that clips the page wrapper with overflow: hidden.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p site/css
cat > site/guide.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Install guide</title>
  <link rel="stylesheet" href="css/docs.css">
</head>
<body>
  <div class="docs-page">
    <header class="docs-page__toolbar">
      <span class="docs-page__title">Install guide</span>
      <a href="#steps">Jump to steps</a>
    </header>
    <article class="docs-page__content">
      <h1>Installing the CLI</h1>
      <p>This guide walks through installing the command-line tool on every supported platform.</p>
      <h2 id="steps">Steps</h2>
      <ol>
        <li>Download the archive for your platform.</li>
        <li>Verify its checksum.</li>
        <li>Move the binary onto your PATH.</li>
      </ol>
    </article>
  </div>
</body>
</html>
HTML
cat > site/css/docs.css <<'CSS'
body {
  margin: 0;
  font-family: system-ui, sans-serif;
  background: #f3f4f6;
}

.docs-page {
  max-inline-size: 60rem;
  margin: 2rem auto;
  background: #ffffff;
  border: 1px solid #e5e7eb;
}

.docs-page__toolbar {
  position: sticky;
  top: 0;
  z-index: 1;
  display: flex;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  background: #ffffff;
  border-block-end: 1px solid #e5e7eb;
}

.docs-page__content {
  padding: 1.5rem;
  line-height: 1.6;
}
CSS
git add -A
git commit -qm "Docs page with sticky toolbar"
cat > site/css/docs.css <<'CSS'
body {
  margin: 0;
  font-family: system-ui, sans-serif;
  background: #f3f4f6;
}

.docs-page {
  max-inline-size: 60rem;
  margin: 2rem auto;
  background: #ffffff;
  border: 1px solid #e5e7eb;
  border-radius: 16px;
  overflow: hidden;
}

.docs-page__toolbar {
  position: sticky;
  top: 0;
  z-index: 1;
  display: flex;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  background: #ffffff;
  border-block-end: 1px solid #e5e7eb;
}

.docs-page__content {
  padding: 1.5rem;
  line-height: 1.6;
}
CSS
