#!/bin/bash
# A project targeting Baseline widely available, plus an uncommitted pricing
# section written correctly in modern CSS that every target supports.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/styles
cat > package.json <<'JSON'
{
  "name": "marketing-site",
  "private": true,
  "browserslist": ["baseline widely available"]
}
JSON
cat > src/styles/tokens.css <<'CSS'
:root {
  --color-text: oklch(25% 0.02 260);
  --color-surface: oklch(99% 0.005 260);
  --color-accent: oklch(52% 0.18 260);
  --color-border: oklch(88% 0.01 260);
  --radius: 12px;
  --space-2: 0.5rem;
  --space-4: 1rem;
  --space-6: 1.5rem;
}
CSS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Pricing</title>
  <link rel="stylesheet" href="src/styles/tokens.css">
  <link rel="stylesheet" href="src/styles/pricing.css">
</head>
<body>
  <main>
    <section class="pricing">
      <div class="pricing__plans">
        <article class="plan">
          <h2 class="plan__name">Starter</h2>
          <p class="plan__price">$0</p>
          <a class="plan__cta" href="/signup?plan=starter">Get started</a>
        </article>
        <article class="plan plan--featured">
          <h2 class="plan__name">Team <span class="plan__badge">Popular</span></h2>
          <p class="plan__price">$12</p>
          <a class="plan__cta" href="/signup?plan=team">Start trial</a>
        </article>
      </div>
    </section>
  </main>
</body>
</html>
HTML
git add -A
git commit -qm "Pricing page shell"
cat > src/styles/pricing.css <<'CSS'
.pricing {
  container: plans / inline-size;
  padding-block: var(--space-6);
  padding-inline: var(--space-4);
}

.pricing__plans {
  display: grid;
  gap: var(--space-4);
}

.plan {
  display: grid;
  gap: var(--space-2);
  padding: var(--space-6);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  color: var(--color-text);
  background: var(--color-surface);

  &:has(.plan__badge) {
    border-color: var(--color-accent);
    background: color-mix(in oklch, var(--color-accent) 6%, var(--color-surface));
  }
}

.plan__name {
  margin: 0;
  font-size: 1.25rem;
}

.plan__badge {
  margin-inline-start: var(--space-2);
  padding-inline: var(--space-2);
  border-radius: 999px;
  font-size: 0.75rem;
  color: var(--color-surface);
  background: var(--color-accent);
}

.plan__price {
  margin: 0;
  font-size: 2rem;
  font-weight: 700;
}

.plan__cta {
  justify-self: start;
  padding: 0.625rem 1rem;
  border-radius: 6px;
  color: var(--color-surface);
  background: var(--color-accent);
  text-decoration: none;
  transition: background-color 150ms ease;

  &:hover {
    background: color-mix(in oklch, var(--color-accent) 85%, black);
  }

  &:focus-visible {
    outline: 3px solid var(--color-accent);
    outline-offset: 3px;
  }
}

@container plans (min-width: 40rem) {
  .pricing__plans {
    grid-template-columns: repeat(2, minmax(0, 1fr));
    align-items: start;
  }
}

@media (prefers-reduced-motion: reduce) {
  .plan__cta {
    transition: none;
  }
}
CSS
