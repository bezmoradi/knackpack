#!/bin/bash
# A site whose semantic tokens switch for dark mode, plus an uncommitted promo
# card that mixes a token background with a hard-coded text color.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p styles
cat > styles/tokens.css <<'CSS'
:root {
  color-scheme: light dark;

  --gray-50: #f9fafb;
  --gray-200: #e5e7eb;
  --gray-700: #374151;
  --gray-900: #111827;
  --gray-950: #030712;
  --blue-600: #2563eb;
  --blue-400: #60a5fa;

  --color-surface: var(--gray-50);
  --color-surface-raised: #ffffff;
  --color-text: var(--gray-900);
  --color-text-muted: var(--gray-700);
  --color-border: var(--gray-200);
  --color-action: var(--blue-600);
}

@media (prefers-color-scheme: dark) {
  :root {
    --color-surface: var(--gray-950);
    --color-surface-raised: var(--gray-900);
    --color-text: var(--gray-50);
    --color-text-muted: var(--gray-200);
    --color-border: var(--gray-700);
    --color-action: var(--blue-400);
  }
}
CSS
cat > styles/home.css <<'CSS'
@import "tokens.css";

body {
  margin: 0;
  font-family: system-ui, sans-serif;
  color: var(--color-text);
  background: var(--color-surface);
}

.feature-list__item {
  padding: 1rem;
  border: 1px solid var(--color-border);
  border-radius: 10px;
  background: var(--color-surface-raised);
}

.feature-list__item p {
  color: var(--color-text-muted);
}
CSS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="color-scheme" content="light dark">
  <title>Home</title>
  <link rel="stylesheet" href="styles/home.css">
</head>
<body>
  <main>
    <section class="promo-card">
      <h2 class="promo-card__title">Try Teams free for 30 days</h2>
      <p class="promo-card__text">Shared projects, roles and billing in one place.</p>
      <a class="promo-card__link" href="/teams">Start trial</a>
    </section>
    <ul class="feature-list">
      <li class="feature-list__item"><h3>Projects</h3><p>Organize work by client.</p></li>
    </ul>
  </main>
</body>
</html>
HTML
git add -A
git commit -qm "Home page and tokens"
cat >> styles/home.css <<'CSS'

.promo-card {
  display: grid;
  gap: 0.5rem;
  padding: 1.5rem;
  border-radius: 12px;
  background: var(--color-surface-raised);
  border: 1px solid var(--color-border);
  color: #374151;
}

.promo-card__title {
  margin: 0;
  font-size: 1.375rem;
  color: #111827;
}

.promo-card__link {
  justify-self: start;
  font-weight: 600;
  color: var(--color-action);
}
CSS
