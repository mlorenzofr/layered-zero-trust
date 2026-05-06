{{/*
Expand the name of the chart.
*/}}
{{- define "rhtpa-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "rhtpa-operator.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "rhtpa-operator.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "rhtpa-operator.labels" -}}
helm.sh/chart: {{ include "rhtpa-operator.chart" . }}
{{ include "rhtpa-operator.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "rhtpa-operator.selectorLabels" -}}
app.kubernetes.io/name: {{ include "rhtpa-operator.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Generate the URL of the OIDC service
*/}}
{{- define "rhtpa-operator.oidc.url" -}}
{{- if not .Values.rhtpa.zeroTrust.oidc.authServerUrl }}
{{- printf "https://keycloak.%s/realms/%s" .Values.global.localClusterDomain .Values.rhtpa.zeroTrust.oidc.realm -}}
{{- else }}
{{- printf "%s" .Values.rhtpa.zeroTrust.oidc.authServerUrl -}}
{{- end }}
{{- end }}

{{/*
Generate the OIDC configuration
*/}}
{{- define "rhtpa-operator.oidc.config" -}}
oidc:
        issuerUrl: {{ include "rhtpa-operator.oidc.url" . }}
{{- if ne .Values.rhtpa.zeroTrust.oidc.clients.cli.apiId "" }}
        uiScopes: \"openid profile email offline_access api://{{ .Values.rhtpa.zeroTrust.oidc.clients.cli.apiId }}/create:document api://{{ .Values.rhtpa.zeroTrust.oidc.clients.cli.apiId }}/read:document api://{{ .Values.rhtpa.zeroTrust.oidc.clients.cli.apiId }}/update:document api://{{ .Values.rhtpa.zeroTrust.oidc.clients.cli.apiId }}/delete:document\"
        loadUser: false
{{- end }}
        clients:
          frontend:
            clientId: {{ .Values.rhtpa.zeroTrust.oidc.clients.frontend.clientId }}
          cli:
            clientId: {{ .Values.rhtpa.zeroTrust.oidc.clients.cli.clientId }}
            clientSecret:
              valueFrom:
                secretKeyRef:
                  name: {{ .Values.rhtpa.zeroTrust.oidc.clients.cli.secretName }}
                  key: client-secret
{{- end }}

{{/*
Generate the authenticator configuration
*/}}
{{- define "rhtpa-operator.authenticator.config" -}}
{{- if ne .Values.rhtpa.zeroTrust.oidc.clients.cli.apiId "" }}
      authenticator:
        configMapRef:
          name: server-entra-auth
          key: auth.yaml
{{- else }}
      authenticator: {}
{{- end }}
{{- end }}
