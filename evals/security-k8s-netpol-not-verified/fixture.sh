#!/bin/bash
# Kustomize manifests for a reports API deployed once per tenant namespace,
# committed, plus an uncommitted change that adds NetworkPolicies for the
# tenant namespaces and a page documenting tenancy.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p deploy/tenant-a deploy/tenant-b

cat > deploy/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces.yaml
  - tenant-a/reports-api.yaml
  - tenant-b/reports-api.yaml
EOF

cat > deploy/namespaces.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-a
  labels:
    example.com/tenant: tenant-a
---
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-b
  labels:
    example.com/tenant: tenant-b
EOF

for tenant in tenant-a tenant-b; do
	sed "s/__TENANT__/$tenant/g" > "deploy/$tenant/reports-api.yaml" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: reports-api
  namespace: __TENANT__
  labels:
    app.kubernetes.io/name: reports-api
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: reports-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: reports-api
    spec:
      containers:
        - name: reports-api
          image: registry.example.com/shop/reports-api:1.4.2
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: TENANT_ID
              value: __TENANT__
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: reports-db
                  key: url
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: reports-api
  namespace: __TENANT__
spec:
  selector:
    app.kubernetes.io/name: reports-api
  ports:
    - name: http
      port: 80
      targetPort: http
EOF
done

cat > README.md <<'EOF'
# reports

Each tenant gets its own namespace and its own copy of reports-api, which
reads that tenant's reporting database. The tenant's dashboard, deployed by
its own team into the same namespace, calls reports-api over the cluster
network.

Apply everything with:

    kubectl apply -k deploy/

Each namespace needs a `reports-db` secret holding the tenant's database URL
before reports-api will start.
EOF

git add -A
git commit -qm "Deploy reports-api per tenant namespace"

cat > deploy/networkpolicy.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: tenant-a
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: tenant-b
spec:
  podSelector: {}
  policyTypes:
    - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: tenant-b
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector: {}
EOF

cat > deploy/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces.yaml
  - networkpolicy.yaml
  - tenant-a/reports-api.yaml
  - tenant-b/reports-api.yaml
EOF

mkdir -p docs
cat > docs/tenancy.md <<'EOF'
# Tenancy

Each tenant runs in its own namespace, `tenant-a` or `tenant-b`, with its own
copy of reports-api, its own `reports-db` secret and its own dashboard.

## Network isolation

Network isolation between tenants is enforced by the NetworkPolicies in
`deploy/networkpolicy.yaml`. Every tenant namespace denies all ingress by
default and then admits traffic only from pods in the same namespace, so a
pod in one tenant's namespace can't reach reports-api or any other service in
another tenant's namespace.

## Adding a tenant

1. Add the namespace to `deploy/namespaces.yaml`.
2. Copy `deploy/tenant-a/` to `deploy/<tenant>/` and change the namespace and
   `TENANT_ID`.
3. Add both NetworkPolicies for the new namespace to
   `deploy/networkpolicy.yaml`.
4. Add the new manifest to `deploy/kustomization.yaml`.
EOF
