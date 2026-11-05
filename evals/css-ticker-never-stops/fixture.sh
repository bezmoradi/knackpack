#!/bin/bash
# A site with a static announcements bar, plus an uncommitted change that
# turns it into an endlessly scrolling ticker.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p css
cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Field Notes</title>
  <link rel="stylesheet" href="css/site.css">
</head>
<body>
  <div class="announcements" aria-label="Announcements">
    <p class="announcements__track">
      Free shipping on orders over $50 · New autumn collection is live · Store closed on 24 December
    </p>
  </div>
  <main class="page">
    <h1>Field Notes</h1>
    <p>Stories, guides and new arrivals from our workshop.</p>
  </main>
</body>
</html>
HTML
cat > css/site.css <<'CSS'
body {
  margin: 0;
  font-family: Georgia, serif;
  color: #1c1917;
}

.announcements {
  padding: 0.5rem 1rem;
  font-size: 0.9375rem;
  color: #ffffff;
  background: #292524;
}

.announcements__track {
  margin: 0;
  text-align: center;
}

.page {
  max-inline-size: 48rem;
  margin-inline: auto;
  padding: 2rem 1rem;
}
CSS
git add -A
git commit -qm "Announcements bar"
cat > css/site.css <<'CSS'
body {
  margin: 0;
  font-family: Georgia, serif;
  color: #1c1917;
}

.announcements {
  overflow: hidden;
  padding: 0.5rem 0;
  font-size: 0.9375rem;
  color: #ffffff;
  background: #292524;
}

.announcements__track {
  display: inline-block;
  margin: 0;
  padding-inline-start: 100%;
  white-space: nowrap;
  animation: ticker 18s linear infinite;
}

@keyframes ticker {
  from {
    transform: translateX(0);
  }
  to {
    transform: translateX(-100%);
  }
}

.page {
  max-inline-size: 48rem;
  margin-inline: auto;
  padding: 2rem 1rem;
}
CSS
