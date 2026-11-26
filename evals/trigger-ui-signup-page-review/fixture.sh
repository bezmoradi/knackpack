#!/bin/bash
# A small React signup page. The user asks how the running page looks and
# works on a phone and with a keyboard, which is the UI reviewer's job, not
# the CSS reviewer's. No server runs in the case; it checks only which
# reviewer starts.
set -euo pipefail
git init -q -b main
git config user.name "Ines Duarte"
git config user.email "ines@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "signup-web",
  "private": true,
  "type": "module",
  "scripts": { "dev": "vite" },
  "dependencies": { "react": "19.1.0", "react-dom": "19.1.0" },
  "devDependencies": { "vite": "7.0.0", "@vitejs/plugin-react": "5.0.0" }
}
JSON
cat > src/Signup.jsx <<'JSX'
import "./signup.css";

export function Signup() {
  return (
    <div className="signup">
      <h1>Create your account</h1>
      <div className="field">
        <span>Email</span>
        <input type="email" placeholder="Email address" />
      </div>
      <div className="field">
        <span>Password</span>
        <input type="password" />
      </div>
      <div className="submit" onClick={() => alert("Account created")}>Sign up</div>
    </div>
  );
}
JSX
cat > src/signup.css <<'CSS'
.signup { width: 480px; margin: 4rem auto; padding: 2rem; }
.field { display: flex; gap: 0.5rem; margin-bottom: 1rem; }
.field input { width: 320px; padding: 0.5rem; border: 1px solid #ddd; }
.submit { background: #7aa7ff; color: #fff; padding: 0.75rem; text-align: center; cursor: pointer; }
CSS
git add -A
git commit -qm "Signup page"
