#!/bin/bash
# A TypeScript component with a typed custom event, plus an uncommitted change
# to the dispatched detail that leaves the global declaration unchanged.
set -euo pipefail
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/components src/pages
cat > package.json <<'JSON'
{
  "name": "catalog-ui",
  "private": true,
  "type": "module",
  "scripts": { "typecheck": "tsc --noEmit" },
  "devDependencies": { "typescript": "^5.9.0" }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "strict": true,
    "noEmit": true
  },
  "include": ["src"]
}
JSON
cat > src/components/option-list.ts <<'TS'
export type OptionSelectDetail = { id: number };

export class OptionList extends HTMLElement {
  connectedCallback(): void {
    this.addEventListener('click', this.#onClick);
  }

  disconnectedCallback(): void {
    this.removeEventListener('click', this.#onClick);
  }

  #onClick = (event: Event): void => {
    const option = (event.target as Element).closest<HTMLElement>('[role="option"]');
    if (!option || !this.contains(option)) return;
    for (const other of this.querySelectorAll('[role="option"]')) {
      other.setAttribute('aria-selected', String(other === option));
    }
    this.dispatchEvent(new CustomEvent<OptionSelectDetail>('option-select', {
      bubbles: true,
      detail: { id: Number(option.dataset.id) },
    }));
  };
}

customElements.define('option-list', OptionList);

declare global {
  interface HTMLElementTagNameMap {
    'option-list': OptionList;
  }
  interface HTMLElementEventMap {
    'option-select': CustomEvent<OptionSelectDetail>;
  }
}
TS
cat > src/pages/filters.ts <<'TS'
import '../components/option-list.js';

const categories = new Map<number, string>([[1, 'Tents'], [2, 'Sleeping bags'], [3, 'Stoves']]);

document.querySelector('option-list')?.addEventListener('option-select', (event) => {
  const category = categories.get(event.detail.id);
  if (!category) return;
  const params = new URLSearchParams(location.search);
  params.set('category', category);
  location.search = params.toString();
});
TS
git add -A
git commit -qm "Category filter with option-list"
cat > src/components/option-list.ts <<'TS'
export type OptionSelectDetail = { id: number };

export class OptionList extends HTMLElement {
  connectedCallback(): void {
    this.addEventListener('click', this.#onClick);
  }

  disconnectedCallback(): void {
    this.removeEventListener('click', this.#onClick);
  }

  #onClick = (event: Event): void => {
    const option = (event.target as Element).closest<HTMLElement>('[role="option"]');
    if (!option || !this.contains(option)) return;
    for (const other of this.querySelectorAll('[role="option"]')) {
      other.setAttribute('aria-selected', String(other === option));
    }
    // Pass the option's id through as-is; parsing it here was lossy for ids like "007".
    this.dispatchEvent(new CustomEvent('option-select', {
      bubbles: true,
      detail: { optionId: option.dataset.id },
    }));
  };
}

customElements.define('option-list', OptionList);

declare global {
  interface HTMLElementTagNameMap {
    'option-list': OptionList;
  }
  interface HTMLElementEventMap {
    'option-select': CustomEvent<OptionSelectDetail>;
  }
}
TS
