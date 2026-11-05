#!/bin/bash
# A message composer, plus an uncommitted attachments list whose file names
# are meant to truncate inside a flex row.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p ui/css
cat > ui/composer.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Compose</title>
  <link rel="stylesheet" href="css/composer.css">
</head>
<body>
  <form class="composer">
    <textarea class="composer__input" aria-label="Message"></textarea>
    <ul class="attachments">
      <li class="attachment">
        <span class="attachment__icon" aria-hidden="true">📎</span>
        <span class="attachment__text">
          <span class="attachment__name">Q3-board-pack-final-v7-with-appendix-and-signed-minutes-2026-10-31.pdf</span>
          <span class="attachment__size">2.4 MB</span>
        </span>
        <button class="attachment__remove" type="button" aria-label="Remove attachment">×</button>
      </li>
    </ul>
    <button class="composer__send" type="submit">Send</button>
  </form>
</body>
</html>
HTML
cat > ui/css/composer.css <<'CSS'
.composer {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  inline-size: min(100%, 32rem);
  padding: 1rem;
  border: 1px solid #d1d5db;
  border-radius: 10px;
}

.composer__input {
  min-block-size: 6rem;
  padding: 0.5rem;
  font: inherit;
}
CSS
git add -A
git commit -qm "Composer"
cat >> ui/css/composer.css <<'CSS'

.attachments {
  margin: 0;
  padding: 0;
  list-style: none;
}

.attachment + .attachment {
  margin-block-start: 0.5rem;
}

.attachment {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.375rem 0.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
}

.attachment__text {
  display: flex;
  flex-direction: column;
  flex: 1;
}

.attachment__name {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.attachment__size {
  font-size: 0.8125rem;
  color: #4b5563;
}

.attachment__remove {
  flex-shrink: 0;
  inline-size: 1.75rem;
  block-size: 1.75rem;
  border: 0;
  border-radius: 50%;
  background: #f3f4f6;
}
CSS
