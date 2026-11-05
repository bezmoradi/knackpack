#!/bin/bash
# A profile card that switched from a viewport media query to a container
# query that the card applies to itself.
set -euo pipefail
git init -q
git config user.name "Robin Ellis"
git config user.email "robin@example.com"
mkdir -p css
cat > package.json <<'JSON'
{
  "name": "team-directory",
  "private": true,
  "browserslist": ["baseline widely available"]
}
JSON
cat > directory.html <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Team</title>
  <link rel="stylesheet" href="css/profile-card.css">
</head>
<body>
  <div class="layout">
    <aside class="layout__sidebar">
      <article class="profile-card">
        <img class="profile-card__avatar" src="ana.jpg" alt="">
        <div class="profile-card__body">
          <h2 class="profile-card__name">Ana Lima</h2>
          <p class="profile-card__role">Design lead</p>
        </div>
      </article>
    </aside>
    <main class="layout__main">
      <article class="profile-card">
        <img class="profile-card__avatar" src="kai.jpg" alt="">
        <div class="profile-card__body">
          <h2 class="profile-card__name">Kai Moreno</h2>
          <p class="profile-card__role">Engineering manager</p>
        </div>
      </article>
    </main>
  </div>
</body>
</html>
HTML
cat > css/profile-card.css <<'CSS'
.layout {
  display: grid;
  grid-template-columns: 16rem 1fr;
  gap: 1.5rem;
}

.profile-card {
  display: grid;
  gap: 0.75rem;
  padding: 1rem;
  border: 1px solid #d4d4d8;
  border-radius: 12px;
}

.profile-card__avatar {
  inline-size: 4rem;
  aspect-ratio: 1;
  border-radius: 50%;
  object-fit: cover;
}

@media (min-width: 48rem) {
  .profile-card {
    grid-template-columns: auto 1fr;
    align-items: center;
  }
}
CSS
git add -A
git commit -qm "Profile cards"
cat > css/profile-card.css <<'CSS'
.layout {
  display: grid;
  grid-template-columns: 16rem 1fr;
  gap: 1.5rem;
}

.profile-card {
  container-type: inline-size;
  container-name: profile-card;
  display: grid;
  gap: 0.75rem;
  padding: 1rem;
  border: 1px solid #d4d4d8;
  border-radius: 12px;
}

.profile-card__avatar {
  inline-size: 4rem;
  aspect-ratio: 1;
  border-radius: 50%;
  object-fit: cover;
}

@container profile-card (min-width: 24rem) {
  .profile-card {
    grid-template-columns: auto 1fr;
    align-items: center;
  }
}
CSS
