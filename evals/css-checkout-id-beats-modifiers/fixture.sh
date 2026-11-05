#!/bin/bash
# A shop with BEM-style button modifiers, plus an uncommitted checkout theme
# that targets buttons through the page's ID.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p styles
cat > styles/buttons.css <<'CSS'
.btn {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.625rem 1rem;
  border: 1px solid transparent;
  border-radius: 6px;
  font: inherit;
  font-weight: 600;
  color: #ffffff;
  background: #1d4ed8;
  cursor: pointer;
}

.btn:hover {
  background: #1e40af;
}

.btn--secondary {
  color: #1f2937;
  background: #ffffff;
  border-color: #9ca3af;
}

.btn--danger {
  color: #ffffff;
  background: #b91c1c;
}

.btn--danger:hover {
  background: #991b1b;
}
CSS
cat > checkout.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Checkout</title>
  <link rel="stylesheet" href="styles/buttons.css">
  <link rel="stylesheet" href="styles/checkout.css">
</head>
<body>
  <main id="checkout" class="checkout">
    <ul class="cart">
      <li class="cart__item">
        <span class="cart__name">Kettle</span>
        <button class="btn btn--danger" type="button">Remove item</button>
      </li>
      <li class="cart__item">
        <span class="cart__name">Mug</span>
        <button class="btn btn--danger" type="button">Remove item</button>
      </li>
    </ul>
    <div class="checkout__actions">
      <a class="btn btn--secondary" href="/cart">Back to cart</a>
      <button class="btn" type="submit">Pay now</button>
    </div>
  </main>
</body>
</html>
HTML
cat > styles/checkout.css <<'CSS'
.checkout {
  max-inline-size: 40rem;
  margin-inline: auto;
  padding: 1.5rem;
}

.cart__item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-block: 0.75rem;
  border-block-end: 1px solid #e5e7eb;
}
CSS
git add -A
git commit -qm "Checkout page"
cat >> styles/checkout.css <<'CSS'

/* Checkout uses the larger, rounder buttons from the new brand guide. */
#checkout .btn {
  padding: 0.875rem 1.5rem;
  border-radius: 999px;
  font-size: 1.0625rem;
  background: #2563eb;
}

#checkout .btn:hover {
  background: #1d4ed8;
}
CSS
