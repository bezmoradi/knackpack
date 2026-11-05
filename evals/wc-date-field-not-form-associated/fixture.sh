#!/bin/bash
# A booking form, plus an uncommitted date-field that uses ElementInternals
# form APIs without declaring itself form-associated.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Book a table</title>
</head>
<body>
  <form id="booking" action="/bookings" method="post">
    <label>Name <input name="name" required></label>
    <label>Date <input type="date" name="date" required></label>
    <button>Book</button>
  </form>
</body>
</html>
HTML
git add -A
git commit -qm "Booking form"
cat > src/components/date-field.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: inline-flex; gap: 0.25rem; }
    select { padding: 0.25rem; }
  </style>
  <select class="day" aria-label="Day"></select>
  <select class="month" aria-label="Month"></select>
  <select class="year" aria-label="Year"></select>
`;

class DateField extends HTMLElement {
  #internals;

  constructor() {
    super();
    this.#internals = this.attachInternals();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  connectedCallback() {
    const root = this.shadowRoot;
    const options = (select, values) => select.replaceChildren(
      new Option('', ''),
      ...values.map((v) => new Option(String(v), String(v).padStart(2, '0'))),
    );
    options(root.querySelector('.day'), Array.from({ length: 31 }, (_, i) => i + 1));
    options(root.querySelector('.month'), Array.from({ length: 12 }, (_, i) => i + 1));
    const year = new Date().getFullYear();
    root.querySelector('.year').replaceChildren(new Option('', ''), new Option(String(year)), new Option(String(year + 1)));
    root.addEventListener('change', () => this.#update());
    this.#update();
  }

  get value() {
    const root = this.shadowRoot;
    const [d, m, y] = ['.day', '.month', '.year'].map((s) => root.querySelector(s).value);
    return d && m && y ? `${y}-${m}-${d}` : '';
  }

  #update() {
    this.#internals.setFormValue(this.value);
    if (this.hasAttribute('required') && !this.value) {
      this.#internals.setValidity({ valueMissing: true }, 'Choose a date.', this.shadowRoot.querySelector('.day'));
    } else {
      this.#internals.setValidity({});
    }
  }
}

customElements.define('date-field', DateField);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Book a table</title>
  <script type="module" src="src/components/date-field.js"></script>
</head>
<body>
  <form id="booking" action="/bookings" method="post">
    <label>Name <input name="name" required></label>
    <span id="date-label">Date</span>
    <date-field name="date" required aria-labelledby="date-label"></date-field>
    <button>Book</button>
  </form>
</body>
</html>
HTML
