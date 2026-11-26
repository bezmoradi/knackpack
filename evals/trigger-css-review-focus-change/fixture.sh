#!/bin/bash
# A small site's button styles. The uncommitted change restyles buttons and
# removes the focus outline in favour of a subtle shadow. The case is about
# which component starts for a stylesheet review, not about the defect.
set -euo pipefail
git init -q -b main
git config user.name "Dana Kowalski"
git config user.email "dana@example.com"
mkdir -p styles
cat > styles/buttons.css <<'CSS'
.button {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border: 1px solid #1f5fbf;
  border-radius: 6px;
  background: #1f5fbf;
  color: #fff;
  font: inherit;
  cursor: pointer;
}
.button:hover { background: #194f9f; }
.button:focus-visible { outline: 2px solid #1f5fbf; outline-offset: 2px; }
.button--secondary { background: #fff; color: #1f5fbf; }
CSS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><title>Settings</title><link rel="stylesheet" href="styles/buttons.css"></head>
<body>
  <form>
    <label>Display name <input name="name"></label>
    <button class="button" type="submit">Save</button>
    <button class="button button--secondary" type="reset">Cancel</button>
  </form>
</body>
</html>
HTML
git add -A
git commit -qm "Button styles"
cat > styles/buttons.css <<'CSS'
.button {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.625rem 1.25rem;
  border: 0;
  border-radius: 999px;
  background: #1f5fbf;
  color: #fff;
  font: inherit;
  font-weight: 600;
  cursor: pointer;
  transition: background 120ms ease, box-shadow 120ms ease;
}
.button:hover { background: #194f9f; }
.button:focus { outline: none; box-shadow: 0 0 0 1px rgba(31, 95, 191, 0.25); }
.button--secondary { background: #e9f0fb; color: #1f5fbf; }
CSS
