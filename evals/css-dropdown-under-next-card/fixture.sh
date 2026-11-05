#!/bin/bash
# A storefront whose product cards lift on hover with will-change: transform,
# plus an uncommitted actions dropdown inside each card with a high z-index.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/styles
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Shop</title>
  <link rel="stylesheet" href="src/styles/main.css">
</head>
<body>
  <main class="catalog">
    <ul class="product-grid">
      <li class="product-card">
        <img class="product-card__image" src="kettle.jpg" alt="">
        <h2 class="product-card__title">Kettle</h2>
        <p class="product-card__price">$39</p>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="mug.jpg" alt="">
        <h2 class="product-card__title">Mug</h2>
        <p class="product-card__price">$12</p>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="teapot.jpg" alt="">
        <h2 class="product-card__title">Teapot</h2>
        <p class="product-card__price">$48</p>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="grinder.jpg" alt="">
        <h2 class="product-card__title">Grinder</h2>
        <p class="product-card__price">$64</p>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="scale.jpg" alt="">
        <h2 class="product-card__title">Scale</h2>
        <p class="product-card__price">$29</p>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="filter.jpg" alt="">
        <h2 class="product-card__title">Filter papers</h2>
        <p class="product-card__price">$6</p>
      </li>
    </ul>
  </main>
</body>
</html>
HTML
cat > src/styles/main.css <<'CSS'
:root {
  --space-2: 0.5rem;
  --space-4: 1rem;
  --radius: 12px;
  --color-surface: #ffffff;
  --color-border: #d4d4d8;
  --shadow-raised: 0 8px 24px rgb(0 0 0 / 0.12);
}

.product-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(14rem, 1fr));
  gap: var(--space-4);
  padding: 0;
  list-style: none;
}

.product-card {
  position: relative;
  padding: var(--space-4);
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  transition: transform 150ms ease, box-shadow 150ms ease;
  will-change: transform;
}

.product-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-raised);
}

.product-card__image {
  inline-size: 100%;
  aspect-ratio: 4 / 3;
  object-fit: cover;
  border-radius: calc(var(--radius) - 4px);
}
CSS
git add -A
git commit -qm "Product grid with hover lift"
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Shop</title>
  <link rel="stylesheet" href="src/styles/main.css">
</head>
<body>
  <main class="catalog">
    <ul class="product-grid">
      <li class="product-card">
        <img class="product-card__image" src="kettle.jpg" alt="">
        <h2 class="product-card__title">Kettle</h2>
        <p class="product-card__price">$39</p>
        <details class="product-card__actions">
          <summary class="product-card__actions-toggle">Actions</summary>
          <ul class="product-card__menu">
            <li><a href="/compare?add=kettle">Add to compare</a></li>
            <li><a href="/wishlist?add=kettle">Save for later</a></li>
            <li><a href="/share?item=kettle">Share</a></li>
          </ul>
        </details>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="mug.jpg" alt="">
        <h2 class="product-card__title">Mug</h2>
        <p class="product-card__price">$12</p>
        <details class="product-card__actions">
          <summary class="product-card__actions-toggle">Actions</summary>
          <ul class="product-card__menu">
            <li><a href="/compare?add=mug">Add to compare</a></li>
            <li><a href="/wishlist?add=mug">Save for later</a></li>
            <li><a href="/share?item=mug">Share</a></li>
          </ul>
        </details>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="teapot.jpg" alt="">
        <h2 class="product-card__title">Teapot</h2>
        <p class="product-card__price">$48</p>
        <details class="product-card__actions">
          <summary class="product-card__actions-toggle">Actions</summary>
          <ul class="product-card__menu">
            <li><a href="/compare?add=teapot">Add to compare</a></li>
            <li><a href="/wishlist?add=teapot">Save for later</a></li>
            <li><a href="/share?item=teapot">Share</a></li>
          </ul>
        </details>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="grinder.jpg" alt="">
        <h2 class="product-card__title">Grinder</h2>
        <p class="product-card__price">$64</p>
        <details class="product-card__actions">
          <summary class="product-card__actions-toggle">Actions</summary>
          <ul class="product-card__menu">
            <li><a href="/compare?add=grinder">Add to compare</a></li>
            <li><a href="/wishlist?add=grinder">Save for later</a></li>
            <li><a href="/share?item=grinder">Share</a></li>
          </ul>
        </details>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="scale.jpg" alt="">
        <h2 class="product-card__title">Scale</h2>
        <p class="product-card__price">$29</p>
        <details class="product-card__actions">
          <summary class="product-card__actions-toggle">Actions</summary>
          <ul class="product-card__menu">
            <li><a href="/compare?add=scale">Add to compare</a></li>
            <li><a href="/wishlist?add=scale">Save for later</a></li>
            <li><a href="/share?item=scale">Share</a></li>
          </ul>
        </details>
      </li>
      <li class="product-card">
        <img class="product-card__image" src="filter.jpg" alt="">
        <h2 class="product-card__title">Filter papers</h2>
        <p class="product-card__price">$6</p>
        <details class="product-card__actions">
          <summary class="product-card__actions-toggle">Actions</summary>
          <ul class="product-card__menu">
            <li><a href="/compare?add=filter">Add to compare</a></li>
            <li><a href="/wishlist?add=filter">Save for later</a></li>
            <li><a href="/share?item=filter">Share</a></li>
          </ul>
        </details>
      </li>
    </ul>
  </main>
</body>
</html>
HTML
cat >> src/styles/main.css <<'CSS'

.product-card__actions {
  position: relative;
  margin-block-start: var(--space-2);
}

.product-card__menu {
  position: absolute;
  inset-block-start: calc(100% + var(--space-2));
  inset-inline-start: 0;
  z-index: 1000;
  min-inline-size: 12rem;
  margin: 0;
  padding: var(--space-2);
  list-style: none;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius);
  box-shadow: var(--shadow-raised);
}
CSS
