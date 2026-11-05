#!/bin/bash
# A product review form, plus an uncommitted star-rating element whose
# rating-change event is dispatched from inside its shadow root.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components
cat > src/review-form.js <<'JS'
const form = document.querySelector('#review-form');
form.addEventListener('submit', (event) => {
  event.preventDefault();
  const data = new FormData(form);
  console.log('submitting review', Object.fromEntries(data));
});
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Write a review</title>
  <script type="module" src="src/review-form.js"></script>
</head>
<body>
  <form id="review-form">
    <label>Your review <textarea name="body" required></textarea></label>
    <button>Submit review</button>
  </form>
</body>
</html>
HTML
git add -A
git commit -qm "Review form"
cat > src/components/star-rating.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    button { font-size: 1.5rem; background: none; border: 0; cursor: pointer; }
    button[aria-pressed="true"] { color: #b45309; }
  </style>
  <div role="group" aria-label="Rating">
    <button type="button" data-value="1" aria-label="1 star" aria-pressed="false">★</button>
    <button type="button" data-value="2" aria-label="2 stars" aria-pressed="false">★</button>
    <button type="button" data-value="3" aria-label="3 stars" aria-pressed="false">★</button>
    <button type="button" data-value="4" aria-label="4 stars" aria-pressed="false">★</button>
    <button type="button" data-value="5" aria-label="5 stars" aria-pressed="false">★</button>
  </div>
`;

class StarRating extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
    this.shadowRoot.addEventListener('click', (event) => {
      const button = event.target.closest('button');
      if (!button) return;
      const value = Number(button.dataset.value);
      for (const star of this.shadowRoot.querySelectorAll('button')) {
        star.setAttribute('aria-pressed', String(Number(star.dataset.value) <= value));
      }
      button.dispatchEvent(new CustomEvent('rating-change', {
        bubbles: true,
        detail: { value },
      }));
    });
  }
}

customElements.define('star-rating', StarRating);
JS
cat > src/review-form.js <<'JS'
import './components/star-rating.js';

const form = document.querySelector('#review-form');
const ratingInput = form.querySelector('input[name="rating"]');

form.addEventListener('rating-change', (event) => {
  ratingInput.value = String(event.detail.value);
});

form.addEventListener('submit', (event) => {
  event.preventDefault();
  if (!ratingInput.value) {
    alert('Please choose a rating.');
    return;
  }
  const data = new FormData(form);
  console.log('submitting review', Object.fromEntries(data));
});
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Write a review</title>
  <script type="module" src="src/review-form.js"></script>
</head>
<body>
  <form id="review-form">
    <star-rating></star-rating>
    <input type="hidden" name="rating">
    <label>Your review <textarea name="body" required></textarea></label>
    <button>Submit review</button>
  </form>
</body>
</html>
HTML
