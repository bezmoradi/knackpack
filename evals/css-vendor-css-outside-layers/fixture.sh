#!/bin/bash
# An app that keeps its CSS in cascade layers, plus an uncommitted import of a
# vendor stylesheet outside any layer.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p styles vendor/flatdate
cat > styles/app.css <<'CSS'
@layer reset, base, components, utilities;

@import "reset.css" layer(reset);
@import "components.css" layer(components);

@layer base {
  body {
    margin: 0;
    font-family: system-ui, sans-serif;
    color: #111827;
  }

  a {
    color: #1d4ed8;
    text-decoration-thickness: 0.08em;
  }
}

@layer utilities {
  .visually-hidden {
    position: absolute;
    inline-size: 1px;
    block-size: 1px;
    overflow: hidden;
    clip-path: inset(50%);
    white-space: nowrap;
  }
}
CSS
cat > styles/reset.css <<'CSS'
*, *::before, *::after { box-sizing: border-box; }
button, input, select { font: inherit; }
CSS
cat > styles/components.css <<'CSS'
.button {
  padding: 0.5rem 1rem;
  border: 1px solid #1d4ed8;
  border-radius: 6px;
  color: #ffffff;
  background: #1d4ed8;
}

.button--ghost {
  color: #1d4ed8;
  background: transparent;
}

.nav-link {
  color: #374151;
  text-decoration: none;
}
CSS
cat > vendor/flatdate/flatdate.css <<'CSS'
.flatdate-calendar { display: grid; grid-template-columns: repeat(7, 2.5rem); gap: 2px; }
.flatdate-day { text-align: center; }
button { background: none; border: 0; padding: 0; color: inherit; cursor: pointer; }
a { color: inherit; text-decoration: none; }
CSS
git add -A
git commit -qm "Layered app styles"
cat > styles/app.css <<'CSS'
@layer reset, base, components, utilities;

@import "reset.css" layer(reset);
@import "components.css" layer(components);
@import "../vendor/flatdate/flatdate.css";

@layer base {
  body {
    margin: 0;
    font-family: system-ui, sans-serif;
    color: #111827;
  }

  a {
    color: #1d4ed8;
    text-decoration-thickness: 0.08em;
  }
}

@layer utilities {
  .visually-hidden {
    position: absolute;
    inline-size: 1px;
    block-size: 1px;
    overflow: hidden;
    clip-path: inset(50%);
    white-space: nowrap;
  }
}

.booking-form .flatdate-calendar {
  margin-block-start: 0.5rem;
}
CSS
