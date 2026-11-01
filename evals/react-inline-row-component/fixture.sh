#!/bin/bash
# A Vite + React invoicing screen, committed, plus an uncommitted refactor of
# its line-item rows.
set -euo pipefail
git init -q
git config user.name "Alex Morgan"
git config user.email "alex@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "invoicing-ui",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite", "build": "tsc -b && vite build" },
  "dependencies": { "react": "^19.3.0", "react-dom": "^19.3.0" },
  "devDependencies": {
    "@types/react": "^19.2.0",
    "@types/react-dom": "^19.2.0",
    "@vitejs/plugin-react": "^5.1.0",
    "typescript": "^5.9.0",
    "vite": "^7.2.0"
  }
}
JSON
cat > src/types.ts <<'TS'
export type Line = { id: string; description: string; quantity: number; unitPrice: number };
TS
cat > src/InvoiceEditor.tsx <<'TSX'
import { useState } from "react";
import type { Line } from "./types";

export function InvoiceEditor({ initialLines }: { initialLines: Line[] }) {
  const [lines, setLines] = useState(initialLines);

  function updateLine(id: string, patch: Partial<Line>) {
    setLines((current) => current.map((l) => (l.id === id ? { ...l, ...patch } : l)));
  }

  const total = lines.reduce((sum, l) => sum + l.quantity * l.unitPrice, 0);

  return (
    <table>
      <tbody>
        {lines.map((line) => (
          <tr key={line.id}>
            <td>
              <input
                aria-label="Description"
                value={line.description}
                onChange={(e) => updateLine(line.id, { description: e.target.value })}
              />
            </td>
            <td>
              <input
                aria-label="Quantity"
                type="number"
                value={line.quantity}
                onChange={(e) => updateLine(line.id, { quantity: Number(e.target.value) })}
              />
            </td>
            <td>{(line.quantity * line.unitPrice).toFixed(2)}</td>
          </tr>
        ))}
      </tbody>
      <tfoot>
        <tr>
          <td colSpan={2}>Total</td>
          <td>{total.toFixed(2)}</td>
        </tr>
      </tfoot>
    </table>
  );
}
TSX
git add -A
git commit -q -m "Invoice editor"

# The uncommitted change: pull the row out into its own component, kept inside
# the editor so it can use updateLine without passing it down.
cat > src/InvoiceEditor.tsx <<'TSX'
import { useState } from "react";
import type { Line } from "./types";

export function InvoiceEditor({ initialLines }: { initialLines: Line[] }) {
  const [lines, setLines] = useState(initialLines);

  function updateLine(id: string, patch: Partial<Line>) {
    setLines((current) => current.map((l) => (l.id === id ? { ...l, ...patch } : l)));
  }

  // Lives inside the editor so it can reach updateLine directly.
  function LineRow({ line }: { line: Line }) {
    return (
      <tr>
        <td>
          <input
            aria-label="Description"
            value={line.description}
            onChange={(e) => updateLine(line.id, { description: e.target.value })}
          />
        </td>
        <td>
          <input
            aria-label="Quantity"
            type="number"
            value={line.quantity}
            onChange={(e) => updateLine(line.id, { quantity: Number(e.target.value) })}
          />
        </td>
        <td>{(line.quantity * line.unitPrice).toFixed(2)}</td>
      </tr>
    );
  }

  const total = lines.reduce((sum, l) => sum + l.quantity * l.unitPrice, 0);

  return (
    <table>
      <tbody>
        {lines.map((line) => (
          <LineRow key={line.id} line={line} />
        ))}
      </tbody>
      <tfoot>
        <tr>
          <td colSpan={2}>Total</td>
          <td>{total.toFixed(2)}</td>
        </tr>
      </tfoot>
    </table>
  );
}
TSX
