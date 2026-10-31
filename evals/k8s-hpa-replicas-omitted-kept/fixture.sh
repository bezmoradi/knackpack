#!/bin/bash
# A Helm chart for the shop API, charts/api, with a Deployment and its
# ServiceAccount, and the Argo CD Application that deploys it, committed, plus
# an uncommitted change that adds a HorizontalPodAutoscaler for the Deployment,
# switched on in values.yaml, and renders the Deployment's replicas only when
# autoscaling is off.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p charts/api/templates deploy

cat > charts/api/Chart.yaml <<'EOF'
apiVersion: v2
name: api
description: The shop API.
type: application
version: 0.3.0
appVersion: "1.4.2"
EOF

cat > charts/api/values.yaml <<'EOF'
replicaCount: 2

image:
  repository: registry.example.com/shop/api
  # Defaults to the chart's appVersion when empty.
  tag: ""
  pullPolicy: IfNotPresent

serviceAccount:
  # Whether the chart creates the service account.
  create: true
  # The account's name; generated from the release name when empty.
  name: ""

containerPort: 8080

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi
EOF

cat > charts/api/templates/_helpers.tpl <<'EOF'
{{/* The chart's name, cut to the 63 characters a label value allows. */}}
{{- define "api.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* The name for this release's resources. */}}
{{- define "api.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/* Labels the selector uses; they never change between releases. */}}
{{- define "api.selectorLabels" -}}
app.kubernetes.io/name: {{ include "api.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Labels for every resource. */}}
{{- define "api.labels" -}}
{{ include "api.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* The service account the pods run as. */}}
{{- define "api.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "api.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
EOF

cat > charts/api/templates/serviceaccount.yaml <<'EOF'
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "api.serviceAccountName" . }}
  labels:
    {{- include "api.labels" . | nindent 4 }}
{{- end }}
EOF

cat > charts/api/templates/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "api.fullname" . }}
  labels:
    {{- include "api.labels" . | nindent 4 }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "api.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "api.selectorLabels" . | nindent 8 }}
    spec:
      serviceAccountName: {{ include "api.serviceAccountName" . }}
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
      containers:
        - name: api
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort }}
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            periodSeconds: 10
            failureThreshold: 6
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
EOF

cat > deploy/argocd-application.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: shop-api
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://git.example.com/shop/api.git
    targetRevision: main
    path: charts/api
    helm:
      releaseName: api
  destination:
    server: https://kubernetes.default.svc
    namespace: shop
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

cat > README.md <<'EOF'
# shop API

The API's Helm chart is in charts/api. Argo CD deploys it from main, as
deploy/argocd-application.yaml says, to the `shop` namespace of the production
cluster, which runs Kubernetes 1.34 with metrics-server. The chart's
values.yaml holds the production values.
EOF

git add -A
git commit -qm "Add the shop API's Helm chart and its Argo CD Application"

sed -i.orig 's/^version: 0.3.0$/version: 0.4.0/' charts/api/Chart.yaml
rm charts/api/Chart.yaml.orig

cat >> charts/api/values.yaml <<'EOF'

autoscaling:
  # Scale the Deployment on CPU with a HorizontalPodAutoscaler.
  enabled: true
  minReplicas: 3
  maxReplicas: 20
  targetCPUUtilizationPercentage: 70
EOF

sed -i.orig 's/^  replicas: {{ .Values.replicaCount }}$/  {{- if not .Values.autoscaling.enabled }}\
&\
  {{- end }}/' charts/api/templates/deployment.yaml
rm charts/api/templates/deployment.yaml.orig

cat > charts/api/templates/hpa.yaml <<'EOF'
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "api.fullname" . }}
  labels:
    {{- include "api.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "api.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
{{- end }}
EOF

cat > README.md <<'EOF'
# shop API

The API's Helm chart is in charts/api. Argo CD deploys it from main, as
deploy/argocd-application.yaml says, to the `shop` namespace of the production
cluster, which runs Kubernetes 1.34 with metrics-server. The chart's
values.yaml holds the production values.

Load on the API varies through the day, so it scales on CPU between 3 and 20
pods. The API is stateless and holds no database connections, and the cluster
has room for 20 pods.
EOF
