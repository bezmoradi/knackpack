#!/bin/bash
# A Vite + React single-page app for a support desk, committed, plus an
# uncommitted change that adds search-as-you-type over customers.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "support-desk",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "react": "^19.3.0",
    "react-dom": "^19.3.0"
  },
  "devDependencies": {
    "@types/react": "^19.2.0",
    "@types/react-dom": "^19.2.0",
    "@vitejs/plugin-react": "^5.1.0",
    "typescript": "^5.9.0",
    "vite": "^7.2.0"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noEmit": true
  },
  "include": ["src"]
}
JSON
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head><meta charset="UTF-8" /><title>Support desk</title></head>
  <body><div id="root"></div><script type="module" src="/src/main.tsx"></script></body>
</html>
HTML
cat > src/main.tsx <<'TSX'
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { App } from "./App";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
TSX
cat > src/api.ts <<'TS'
export type Customer = { id: string; name: string; email: string; plan: "free" | "pro" };

// The search endpoint can take a second or more for short queries, which
// match many customers, and answers longer queries much faster.
export async function searchCustomers(query: string, signal?: AbortSignal): Promise<Customer[]> {
  const res = await fetch(`/api/customers?q=${encodeURIComponent(query)}`, { signal });
  if (!res.ok) throw new Error(`Search failed: ${res.status}`);
  return res.json();
}
TS
cat > src/App.tsx <<'TSX'
export function App() {
  return (
    <main>
      <h1>Support desk</h1>
    </main>
  );
}
TSX
git add -A
git commit -q -m "Support desk shell"

# The uncommitted change: search as you type, debounced.
cat > src/CustomerSearch.tsx <<'TSX'
import { useEffect, useState } from "react";
import { searchCustomers, type Customer } from "./api";

export function CustomerSearch({ onSelect }: { onSelect: (c: Customer) => void }) {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Customer[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (query.trim().length < 2) {
      setResults([]);
      return;
    }
    // Debounced, so we don't fire a request on every keystroke.
    const timer = setTimeout(() => {
      searchCustomers(query)
        .then((found) => {
          setResults(found);
          setError(null);
        })
        .catch((e: Error) => setError(e.message));
    }, 250);
    return () => clearTimeout(timer);
  }, [query]);

  return (
    <section>
      <input
        type="search"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search customers by name or email"
        aria-label="Search customers"
      />
      {error && <p role="alert">{error}</p>}
      <ul>
        {results.map((c) => (
          <li key={c.id}>
            <button onClick={() => onSelect(c)}>
              {c.name} ({c.email}), {c.plan}
            </button>
          </li>
        ))}
      </ul>
    </section>
  );
}
TSX
cat > src/App.tsx <<'TSX'
import { useState } from "react";
import { CustomerSearch } from "./CustomerSearch";
import type { Customer } from "./api";

export function App() {
  const [selected, setSelected] = useState<Customer | null>(null);
  return (
    <main>
      <h1>Support desk</h1>
      <CustomerSearch onSelect={setSelected} />
      {selected && <p>Working on {selected.name}'s ticket.</p>}
    </main>
  );
}
TSX
