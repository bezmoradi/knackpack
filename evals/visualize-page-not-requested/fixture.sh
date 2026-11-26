#!/bin/bash
# A small TypeScript dashboard front end with two layouts, classic and focus,
# each a set of CSS grid areas per breakpoint. src/shell.ts picks one from the
# user's preference. The two differ at every breakpoint: focus drops the
# sidebar, moves alerts into a header bell and activity into a drawer, and
# puts the chart first.
set -euo pipefail
export GIT_AUTHOR_DATE="2026-11-12T09:30:00Z" GIT_COMMITTER_DATE="2026-11-12T09:30:00Z"
git init -q -b main
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/layouts

cat > README.md <<'EOF'
# ops-dashboard

The operations dashboard. `src/shell.ts` lays out the panels with one of the
layouts in `src/layouts/`, chosen per user in their preferences
(`layout: "classic" | "focus"`). New users get `classic`.

Breakpoints: phone below 640px, tablet from 640px, desktop from 1024px.
EOF

cat > package.json <<'EOF'
{
  "name": "ops-dashboard",
  "private": true,
  "type": "module",
  "scripts": {
    "build": "tsc -p .",
    "typecheck": "tsc -p . --noEmit"
  },
  "devDependencies": {
    "typescript": "5.6.3"
  }
}
EOF

cat > src/layouts/types.ts <<'EOF'
export type Panel = "header" | "nav" | "alerts" | "kpis" | "chart" | "activity";

export type Breakpoint = "phone" | "tablet" | "desktop";

/** Where a panel goes when it isn't in the grid. */
export type Placement = "grid" | "drawer" | "header-menu" | "header-bell" | "bottom-bar";

export interface BreakpointLayout {
  /** CSS grid-template-areas rows; "." is an empty cell. */
  areas: string[];
  columns: string;
  /** Panels not placed in the grid, and where they go instead. */
  offGrid?: Partial<Record<Panel, Exclude<Placement, "grid">>>;
}

export interface Layout {
  name: string;
  breakpoints: Record<Breakpoint, BreakpointLayout>;
}
EOF

cat > src/layouts/classic.ts <<'EOF'
import type { Layout } from "./types.js";

// The layout every user has had since launch: a sidebar on wide screens,
// alerts as a banner, activity always visible.
export const classic: Layout = {
  name: "classic",
  breakpoints: {
    phone: {
      areas: ["header", "alerts", "kpis", "chart", "activity"],
      columns: "1fr",
      offGrid: { nav: "bottom-bar" },
    },
    tablet: {
      areas: [
        "header header",
        "alerts alerts",
        "kpis kpis",
        "chart chart",
        "activity activity",
      ],
      columns: "1fr 1fr",
      offGrid: { nav: "header-menu" },
    },
    desktop: {
      areas: [
        "nav header header",
        "nav alerts alerts",
        "nav kpis kpis",
        "nav chart activity",
      ],
      columns: "240px 2fr 1fr",
    },
  },
};
EOF

cat > src/layouts/focus.ts <<'EOF'
import type { Layout } from "./types.js";

// Chart first, fewer panels on screen: no sidebar, alerts behind the bell in
// the header, activity in a drawer opened from the header.
export const focus: Layout = {
  name: "focus",
  breakpoints: {
    phone: {
      areas: ["header", "chart", "kpis"],
      columns: "1fr",
      offGrid: { nav: "header-menu", alerts: "header-bell", activity: "drawer" },
    },
    tablet: {
      areas: ["header header", "chart chart", "kpis kpis"],
      columns: "1fr 1fr",
      offGrid: { nav: "header-menu", alerts: "header-bell", activity: "drawer" },
    },
    desktop: {
      areas: ["header header", "chart kpis"],
      columns: "3fr 1fr",
      offGrid: { nav: "header-menu", alerts: "header-bell", activity: "drawer" },
    },
  },
};
EOF

cat > src/shell.ts <<'EOF'
import { classic } from "./layouts/classic.js";
import { focus } from "./layouts/focus.js";
import type { Breakpoint, Layout, Panel } from "./layouts/types.js";

const LAYOUTS: Record<string, Layout> = { classic, focus };

export function breakpointFor(width: number): Breakpoint {
  if (width >= 1024) return "desktop";
  if (width >= 640) return "tablet";
  return "phone";
}

export function layoutFor(preference: string | undefined): Layout {
  return LAYOUTS[preference ?? "classic"] ?? classic;
}

/** Applies the layout to the dashboard root and moves off-grid panels. */
export function renderShell(root: HTMLElement, preference: string | undefined): void {
  const layout = layoutFor(preference);
  const bp = layout.breakpoints[breakpointFor(window.innerWidth)];
  root.style.display = "grid";
  root.style.gridTemplateColumns = bp.columns;
  root.style.gridTemplateAreas = bp.areas.map((row) => `"${row}"`).join(" ");
  for (const el of root.querySelectorAll<HTMLElement>("[data-panel]")) {
    const panel = el.dataset.panel as Panel;
    const target = bp.offGrid?.[panel];
    if (target) {
      el.style.gridArea = "";
      el.dataset.placement = target;
      document.getElementById(`slot-${target}`)?.append(el);
    } else {
      el.style.gridArea = panel;
      delete el.dataset.placement;
    }
  }
}
EOF

git add -A
git commit -qm "Dashboard shell with classic and focus layouts"
