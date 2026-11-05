#!/bin/bash
# A café ordering kiosk with a shared list component, plus an uncommitted product
# picker whose narrower onSelect handler type-checks only because of method-shorthand bivariance.
set -euo pipefail
git init -q -b main
git config user.name "Hana Kobayashi"
git config user.email "hana.kobayashi@example.com"
mkdir -p src/ui src/screens src/cart

cat > package.json <<'JSON'
{
  "name": "cafe-kiosk",
  "version": "0.14.1",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "typecheck": "tsc -p . --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.9.3"
  }
}
JSON

cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "es2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "strict": true,
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"]
}
JSON

cat > src/ui/List.ts <<'TS'
export interface ListItem {
  id: string;
  label: string;
  // Section headings render in bold; they're focusable and selectable like
  // any other row so screen readers and the keypad can reach them.
  heading?: boolean;
}

export interface ListProps {
  items: ListItem[];
  onSelect(item: ListItem): void;
}

export interface ListController {
  focusedIndex(): number;
  move(delta: number): void;
  // Called on tap, and when the keypad's OK button is pressed.
  select(index?: number): void;
}

export function createList(props: ListProps): ListController {
  let focused = 0;
  return {
    focusedIndex: () => focused,
    move(delta) {
      focused = Math.min(props.items.length - 1, Math.max(0, focused + delta));
    },
    select(index = focused) {
      focused = index;
      props.onSelect(props.items[index]);
    },
  };
}
TS

cat > src/cart/cart.ts <<'TS'
export class Cart {
  private readonly lines = new Map<string, number>();

  add(sku: string): void {
    this.lines.set(sku, (this.lines.get(sku) ?? 0) + 1);
  }

  entries(): [string, number][] {
    return [...this.lines.entries()];
  }
}
TS

cat > src/screens/languageMenu.ts <<'TS'
import { createList, type ListItem } from "../ui/List.js";

export function languageMenu(setLanguage: (code: string) => void) {
  const items: ListItem[] = [
    { id: "languages", label: "Language", heading: true },
    { id: "en", label: "English" },
    { id: "ja", label: "日本語" },
  ];
  return createList({
    items,
    onSelect(item) {
      if (!item.heading) setLanguage(item.id);
    },
  });
}
TS

git add -A
git commit -q -m "Kiosk list component and language menu"

# Uncommitted: the product picker, grouped into sections.
cat > src/screens/productPicker.ts <<'TS'
import type { Cart } from "../cart/cart.js";
import { createList, type ListItem } from "../ui/List.js";

export interface ProductItem extends ListItem {
  sku: string;
  priceCents: number;
}

export interface MenuSection {
  title: string;
  products: ProductItem[];
}

export function productPicker(sections: MenuSection[], cart: Cart) {
  const items: ListItem[] = sections.flatMap((section) => [
    { id: `section-${section.title}`, label: section.title, heading: true },
    ...section.products,
  ]);

  return createList({
    items,
    onSelect: (item: ProductItem) => cart.add(item.sku),
  });
}
TS
