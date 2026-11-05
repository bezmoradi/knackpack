#!/bin/bash
# A messaging app that ships right-to-left locales, plus an uncommitted unread
# badge styled with physical properties.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p src/i18n src/styles templates
cat > src/i18n/locales.json <<'JSON'
{
  "default": "en",
  "locales": [
    { "code": "en", "dir": "ltr" },
    { "code": "de", "dir": "ltr" },
    { "code": "ar", "dir": "rtl" },
    { "code": "he", "dir": "rtl" }
  ]
}
JSON
cat > templates/layout.html <<'HTML'
<!doctype html>
<html lang="{{ locale.code }}" dir="{{ locale.dir }}">
<head>
  <meta charset="utf-8">
  <link rel="stylesheet" href="/styles/conversations.css">
</head>
<body>
  {{ content }}
</body>
</html>
HTML
cat > templates/conversations.html <<'HTML'
<ul class="conversation-list">
  {% for c in conversations %}
  <li class="conversation-row">
    <img class="conversation-row__avatar" src="{{ c.avatar }}" alt="">
    <div class="conversation-row__text">
      <span class="conversation-row__name">{{ c.name }}</span>
      <span class="conversation-row__preview">{{ c.preview }}</span>
    </div>
    {% if c.unread %}<span class="conversation-row__badge">{{ c.unread }}</span>{% endif %}
  </li>
  {% endfor %}
</ul>
HTML
cat > src/styles/conversations.css <<'CSS'
.conversation-list {
  margin: 0;
  padding: 0;
  list-style: none;
}

.conversation-row {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding-block: 0.75rem;
  padding-inline: 1rem;
  border-block-end: 1px solid #e5e7eb;
}

.conversation-row__avatar {
  inline-size: 2.5rem;
  block-size: 2.5rem;
  border-radius: 50%;
}

.conversation-row__text {
  display: grid;
  min-inline-size: 0;
}

.conversation-row__preview {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  color: #4b5563;
}
CSS
git add -A
git commit -qm "Conversation list"
cat >> src/styles/conversations.css <<'CSS'

.conversation-row__text {
  margin-right: 2.5rem;
  text-align: left;
}

.conversation-row__badge {
  position: absolute;
  top: 50%;
  right: 1rem;
  transform: translateY(-50%);
  min-inline-size: 1.5rem;
  padding: 0.125rem 0.375rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 700;
  text-align: center;
  color: #ffffff;
  background: #b91c1c;
}
CSS
