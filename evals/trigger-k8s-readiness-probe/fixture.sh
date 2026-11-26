#!/bin/bash
# A Kubernetes Deployment with one replica and no probes. The user asks for a
# readiness probe and more replicas, a change to make, not a Kubernetes
# review.
set -euo pipefail
git init -q -b main
git config user.name "Kofi Mensah"
git config user.email "kofi@example.com"
mkdir -p k8s
cat > k8s/deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  labels:
    app: catalog
spec:
  replicas: 1
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
    spec:
      containers:
        - name: catalog
          image: registry.example.com/catalog:1.8.2
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 256Mi
YAML
cat > k8s/service.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: catalog
spec:
  selector:
    app: catalog
  ports:
    - port: 80
      targetPort: 8080
YAML
git add -A
git commit -qm "catalog Deployment and Service"
