#!/bin/bash
# A task list whose items can be pinned to the top, plus an uncommitted
# rewrite of task-item that renders and binds in connectedCallback.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src
cat > src/task-list.js <<'JS'
// Pinning moves a task to the top of the list.
document.querySelector('#tasks').addEventListener('pin', (event) => {
  event.currentTarget.prepend(event.target);
});
JS
cat > src/task-item.js <<'JS'
class TaskItem extends HTMLElement {
  constructor() {
    super();
    const box = document.createElement('input');
    box.type = 'checkbox';
    const pin = document.createElement('button');
    pin.type = 'button';
    pin.textContent = 'Pin';
    pin.addEventListener('click', () => this.dispatchEvent(new Event('pin', { bubbles: true })));
    this.prepend(box);
    this.append(pin);
    this.addEventListener('click', (event) => {
      if (event.target === box) this.toggleAttribute('done', box.checked);
    });
  }
}

customElements.define('task-item', TaskItem);
JS
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Tasks</title>
  <script type="module" src="src/task-item.js"></script>
  <script type="module" src="src/task-list.js"></script>
  <style>task-item { display: flex; gap: 0.5rem; } task-item[done] { text-decoration: line-through; }</style>
</head>
<body>
  <h1>Today</h1>
  <div id="tasks">
    <task-item>Reply to the landlord</task-item>
    <task-item>Book the dentist</task-item>
    <task-item>Renew the passport</task-item>
  </div>
</body>
</html>
HTML
git add -A
git commit -qm "Task list with pinning"
cat > src/task-item.js <<'JS'
class TaskItem extends HTMLElement {
  connectedCallback() {
    const box = document.createElement('input');
    box.type = 'checkbox';
    box.checked = this.hasAttribute('done');
    const pin = document.createElement('button');
    pin.type = 'button';
    pin.textContent = 'Pin';
    pin.addEventListener('click', () => this.dispatchEvent(new Event('pin', { bubbles: true })));
    this.prepend(box);
    this.append(pin);
    this.addEventListener('click', (event) => {
      if (event.target.type === 'checkbox') this.toggleAttribute('done');
    });
  }
}

customElements.define('task-item', TaskItem);
JS
