#!/bin/bash
set -euo pipefail
git init -q
git config user.name "Sam Rivera"
git config user.email "sam@example.com"

# A small service with its server settings but nothing about the load balancer
# in front of it, so its idle timeout can't be known from the repository.
cat > server.py <<'EOF'
import os

from waitress import serve

from app import app

if __name__ == "__main__":
    serve(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8080")), channel_timeout=60)
EOF

cat > app.py <<'EOF'
from flask import Flask

app = Flask(__name__)


@app.get("/health")
def health():
    return {"ok": True}
EOF

cat > Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir flask waitress
CMD ["python", "server.py"]
EOF

git add -A
git commit -qm "Serve the app with waitress"
