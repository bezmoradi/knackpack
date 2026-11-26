#!/bin/bash
# A Compose stack where the worker starts as soon as the api container does,
# before the api answers. The user asks for a healthcheck, a change to make,
# not a Docker review.
set -euo pipefail
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi@example.com"
cat > Dockerfile <<'DOCKER'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
DOCKER
cat > requirements.txt <<'TXT'
fastapi==0.115.0
uvicorn==0.30.6
TXT
cat > compose.yaml <<'YAML'
services:
  api:
    build: .
    ports:
      - "8000:8000"
  worker:
    build: .
    command: ["python", "-m", "app.worker"]
    depends_on:
      - api
YAML
git add -A
git commit -qm "Compose stack for the api and worker"
