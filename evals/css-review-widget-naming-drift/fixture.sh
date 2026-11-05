#!/bin/bash
# A design-system package with a consistent BEM-style convention, plus an
# uncommitted widget whose names drift from it.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p packages/ui/src/components docs
cat > docs/css-conventions.md <<'MD'
# CSS conventions

Class names are lowercase kebab-case in the form `block__element--modifier`.
State uses `is-` or `has-` classes on the block (`is-open`, `has-error`).
Never style bare element names or generic class names outside a block.
MD
cat > packages/ui/src/components/accordion.css <<'CSS'
.accordion {
  border: 1px solid var(--ds-color-border);
  border-radius: var(--ds-radius);
}

.accordion__trigger {
  display: flex;
  justify-content: space-between;
  inline-size: 100%;
  padding: var(--ds-space-3);
}

.accordion__panel {
  padding: var(--ds-space-3);
}

.accordion.is-open .accordion__trigger {
  font-weight: 600;
}
CSS
cat > packages/ui/src/components/tag.css <<'CSS'
.tag {
  display: inline-flex;
  padding-inline: var(--ds-space-2);
  border-radius: 999px;
}

.tag--success {
  background: var(--ds-color-success-subtle);
}
CSS
git add -A
git commit -qm "Accordion and tag components"
cat > packages/ui/src/components/review-widget.css <<'CSS'
.reviewWidget {
  display: grid;
  gap: var(--ds-space-2);
  padding: var(--ds-space-3);
  padding: var(--ds-space-4);
  border: 1px solid var(--ds-color-border);
  border-radius: var(--ds-radius);
}

.reviewWidget .title {
  margin: 0;
  font-weight: 600;
}

.starRow {
  display: flex;
  gap: 2px;
}

.starRow .star {
  inline-size: 1.25rem;
  block-size: 1.25rem;
  color: var(--ds-color-border);
}

.active {
  color: var(--ds-color-warning);
}
CSS
