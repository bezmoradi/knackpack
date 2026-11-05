#!/bin/bash
# A React app with a tag editor, plus an uncommitted switch to the design
# system's tag-chips custom element.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/design-system
cat > package.json <<'JSON'
{
  "name": "notes-app",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "build": "vite build" },
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1"
  },
  "devDependencies": { "vite": "^7.1.0", "@vitejs/plugin-react": "^5.0.0" }
}
JSON
cat > src/design-system/tag-chips.js <<'JS'
const template = document.createElement('template');
template.innerHTML = `
  <style>
    :host { display: flex; flex-wrap: wrap; gap: 0.25rem; }
    .chip { display: inline-flex; align-items: center; gap: 0.25rem; padding: 0 0.5rem; border-radius: 999px; background: #e0e7ff; }
    button { border: 0; background: none; cursor: pointer; }
  </style>
  <div class="chips" role="list"></div>
`;

// <tag-chips>: shows a list of tags. Set the `tags` property to an array of
// strings; removing a chip dispatches `tag-remove` with { tag } in detail.
export class TagChips extends HTMLElement {
  #tags = [];

  constructor() {
    super();
    this.attachShadow({ mode: 'open' }).append(template.content.cloneNode(true));
  }

  get tags() {
    return [...this.#tags];
  }

  set tags(value) {
    this.#tags = Array.isArray(value) ? [...value] : [];
    this.#render();
  }

  #render() {
    const list = this.shadowRoot.querySelector('.chips');
    list.replaceChildren(...this.#tags.map((tag) => {
      const chip = document.createElement('span');
      chip.className = 'chip';
      chip.setAttribute('role', 'listitem');
      chip.textContent = tag;
      const remove = document.createElement('button');
      remove.type = 'button';
      remove.setAttribute('aria-label', `Remove ${tag}`);
      remove.textContent = '×';
      remove.addEventListener('click', () => {
        this.dispatchEvent(new CustomEvent('tag-remove', { bubbles: true, composed: true, detail: { tag } }));
      });
      chip.append(remove);
      return chip;
    }));
  }
}

customElements.define('tag-chips', TagChips);
JS
cat > src/main.jsx <<'JSX'
import { createRoot } from 'react-dom/client';
import { TagEditor } from './TagEditor.jsx';

createRoot(document.getElementById('root')).render(<TagEditor initialTags={['work', 'urgent', 'q3']} />);
JSX
cat > src/TagEditor.jsx <<'JSX'
import { useState } from 'react';

export function TagEditor({ initialTags }) {
  const [tags, setTags] = useState(initialTags);
  return (
    <div className="tag-editor">
      {tags.map((tag) => (
        <span key={tag} className="pill">
          {tag}
          <button type="button" aria-label={`Remove ${tag}`} onClick={() => setTags(tags.filter((t) => t !== tag))}>×</button>
        </span>
      ))}
    </div>
  );
}
JSX
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Notes</title>
</head>
<body>
  <div id="root"></div>
  <script type="module" src="/src/main.jsx"></script>
</body>
</html>
HTML
git add -A
git commit -qm "Tag editor"
cat > src/main.jsx <<'JSX'
import { createRoot } from 'react-dom/client';
import './design-system/tag-chips.js';
import { TagEditor } from './TagEditor.jsx';

createRoot(document.getElementById('root')).render(<TagEditor initialTags={['work', 'urgent', 'q3']} />);
JSX
cat > src/TagEditor.jsx <<'JSX'
import { useState } from 'react';

export function TagEditor({ initialTags }) {
  const [tags, setTags] = useState(initialTags);
  return (
    <div className="tag-editor">
      <tag-chips
        tags={tags}
        ontag-remove={(event) => setTags(tags.filter((t) => t !== event.detail.tag))}
      />
    </div>
  );
}
JSX
