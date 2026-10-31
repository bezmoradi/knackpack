#!/bin/bash
# A Helm chart for the shop API, charts/api, with a Deployment and its
# ServiceAccount, committed, plus an uncommitted change that adds a
# serviceAccount.automount value for the pods' Kubernetes API token, production
# values in values-prod.yaml and a README line on what production pods mount.
set -euo pipefail
git init -q
git config user.name "Eval Fixture"
git config user.email "fixture@example.com"
mkdir -p charts/api/templates

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

cat > README.md <<'EOF'
# shop API

The API's Helm chart is in charts/api. The deploy job installs it in the
`shop` namespace of the production cluster, which runs Kubernetes 1.34, with
Helm 3.19:

    helm upgrade --install api charts/api -n shop
EOF

git add -A
git commit -qm "Add the shop API's Helm chart"

sed -i.orig 's/^version: 0.3.0$/version: 0.4.0/' charts/api/Chart.yaml
rm charts/api/Chart.yaml.orig

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
  # automount: whether the pods mount a Kubernetes API token. Defaults to
  # true; set it to false where the pods never call the Kubernetes API.

containerPort: 8080

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    memory: 256Mi
EOF

cat > charts/api/values-prod.yaml <<'EOF'
replicaCount: 3

serviceAccount:
  # The API never calls the Kubernetes API, so production pods get no token.
  automount: false
EOF

sed -i.orig 's/^      serviceAccountName: {{ include "api.serviceAccountName" . }}$/&\
      automountServiceAccountToken: {{ .Values.serviceAccount.automount | default true }}/' charts/api/templates/deployment.yaml
rm charts/api/templates/deployment.yaml.orig

cat > README.md <<'EOF'
# shop API

The API's Helm chart is in charts/api. The deploy job installs it in the
`shop` namespace of the production cluster, which runs Kubernetes 1.34, with
Helm 3.19 and the production values:

    helm upgrade --install api charts/api -n shop -f charts/api/values-prod.yaml

Production pods must not mount a Kubernetes API token, since the API never
calls the Kubernetes API.
EOF
