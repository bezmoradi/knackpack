#!/bin/bash
# An app's base stylesheet, plus an uncommitted change that removes focus
# outlines on interactive elements without any replacement.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p assets/css
cat > assets/css/base.css <<'CSS'
*,
*::before,
*::after {
  box-sizing: border-box;
}

body {
  margin: 0;
  font-family: system-ui, sans-serif;
  line-height: 1.5;
  color: #111827;
  background: #ffffff;
}

a {
  color: #1d4ed8;
}

button,
input,
select,
textarea {
  font: inherit;
}

button {
  padding: 0.5rem 1rem;
  border: 1px solid #1d4ed8;
  border-radius: 6px;
  color: #ffffff;
  background: #1d4ed8;
}

input,
select,
textarea {
  padding: 0.5rem 0.75rem;
  border: 1px solid #6b7280;
  border-radius: 6px;
}
CSS
cat > settings.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Account settings</title>
  <link rel="stylesheet" href="assets/css/base.css">
</head>
<body>
  <nav><a href="/">Home</a> <a href="/billing">Billing</a> <a href="/settings">Settings</a></nav>
  <main>
    <form>
      <label for="name">Display name</label>
      <input id="name" name="name">
      <label for="tz">Time zone</label>
      <select id="tz" name="tz"><option>UTC</option><option>Europe/Berlin</option></select>
      <button type="submit">Save</button>
    </form>
  </main>
</body>
</html>
HTML
git add -A
git commit -qm "Base styles and settings page"
cat >> assets/css/base.css <<'CSS'

a:focus,
button:focus,
input:focus,
select:focus,
textarea:focus {
  outline: none;
}
CSS
