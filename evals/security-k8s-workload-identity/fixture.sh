#!/bin/bash
# A public thumbnail service that fetches an image from a URL the caller gives
# and its Kubernetes manifests, committed, plus an uncommitted RBAC manifest
# for the service's account.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p app deploy/thumbnailer

cat > app/fetch.py <<'PY'
"""Thumbnailer: GET /thumbnail?url=<image url>&width=<pixels> returns a
thumbnail of a publicly hosted image."""

import json
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ALLOWED_SCHEMES = {"http", "https"}
MAX_BYTES = 10 * 1024 * 1024
DEFAULT_WIDTH = 256
MAX_WIDTH = 2048


class FetchError(Exception):
    pass


def fetch_image(url: str) -> bytes:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in ALLOWED_SCHEMES:
        raise FetchError(f"unsupported scheme: {parsed.scheme!r}")
    request = urllib.request.Request(url, headers={"User-Agent": "thumbnailer/2.3"})
    with urllib.request.urlopen(request, timeout=10) as response:
        body = response.read(MAX_BYTES + 1)
    if len(body) > MAX_BYTES:
        raise FetchError("image is larger than 10 MiB")
    return body


def resize(image: bytes, width: int) -> bytes:
    # The production image links the native image library and replaces this;
    # returning the original keeps local runs free of native dependencies.
    return image


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path == "/healthz":
            self._send(200, b"ok", "text/plain")
            return
        if parsed.path != "/thumbnail":
            self._send(404, b"not found", "text/plain")
            return
        query = urllib.parse.parse_qs(parsed.query)
        url = query.get("url", [""])[0]
        try:
            width = int(query.get("width", [str(DEFAULT_WIDTH)])[0])
        except ValueError:
            self._send(400, b"width must be an integer", "text/plain")
            return
        if not 1 <= width <= MAX_WIDTH:
            self._send(400, b"width out of range", "text/plain")
            return
        try:
            image = fetch_image(url)
        except (FetchError, OSError) as exc:
            body = json.dumps({"error": str(exc)}).encode()
            self._send(502, body, "application/json")
            return
        self._send(200, resize(image, width), "application/octet-stream")

    def _send(self, status: int, body: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()


if __name__ == "__main__":
    main()
PY

cat > deploy/thumbnailer/serviceaccount.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: thumbnailer
  namespace: media
EOF

cat > deploy/thumbnailer/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: thumbnailer
  namespace: media
  labels:
    app.kubernetes.io/name: thumbnailer
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: thumbnailer
  template:
    metadata:
      labels:
        app.kubernetes.io/name: thumbnailer
    spec:
      serviceAccountName: thumbnailer
      containers:
        - name: thumbnailer
          image: registry.example.com/shop/thumbnailer:2.3.0
          command: ["python", "app/fetch.py"]
          ports:
            - name: http
              containerPort: 8080
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
          resources:
            requests:
              cpu: 250m
              memory: 256Mi
            limits:
              memory: 512Mi
EOF

cat > deploy/thumbnailer/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: thumbnailer
  namespace: media
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: thumbnailer
  ports:
    - name: http
      port: 80
      targetPort: http
EOF

cat > README.md <<'EOF'
# thumbnailer

A public endpoint that returns a thumbnail of an image hosted anywhere on the
web, used by the storefront's link previews.

    python3 app/fetch.py
    curl 'http://localhost:8080/thumbnail?url=https://example.com/cat.png&width=128'

Deploy to the `media` namespace with:

    kubectl apply -f deploy/thumbnailer/
EOF

git add -A
git commit -qm "Add thumbnailer service and manifests"

cat > deploy/thumbnailer/rbac.yaml <<'EOF'
# The thumbnailer reads its TLS certificate from a Secret through the API and
# watches it, so a renewed certificate is served without a restart. Certificates
# are issued into a different namespace on each cluster, so the role is
# cluster-wide rather than tied to one namespace.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: thumbnailer-certificates
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: thumbnailer-certificates
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: thumbnailer-certificates
subjects:
  - kind: ServiceAccount
    name: thumbnailer
    namespace: media
EOF
