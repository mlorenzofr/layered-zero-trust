{{/*
Create the image path for the passed in image field.
When global.registry is enabled with domain and repository, the image
reference is derived from global.registry.domain/repository (e.g.
quay.io/ztvp/qtodo) so no VP --set override is needed.
*/}}
{{- define "qtodo.image" -}}
{{- $name := tpl .value.name .context -}}
{{- $useRegistry := default false .useRegistry -}}
{{- if and $useRegistry .context.Values.global.registry.enabled .context.Values.global.registry.domain .context.Values.global.registry.repository -}}
{{- $name = printf "%s/%s" (tpl .context.Values.global.registry.domain .context) .context.Values.global.registry.repository -}}
{{- end -}}
{{- if eq (substr 0 7 (tpl .value.version .context)) "sha256:" -}}
{{- printf "%s@%s" $name (tpl .value.version .context) -}}
{{- else -}}
{{- printf "%s:%s" $name (tpl .value.version .context) -}}
{{- end -}}
{{- end -}}

{{/*
Generate the URL of the OIDC service
*/}}
{{- define "qtodo.oidc.url" }}
{{- if .Values.app.oidc.authServerUrl }}
{{- print .Values.app.oidc.authServerUrl }}
{{- else if eq .Values.app.oidc.provider "entraid" }}
{{- if not .Values.app.oidc.entraid.tenantId }}
{{- fail "app.oidc.entraid.tenantId is required when using Entra ID provider" }}
{{- end }}
{{- printf "https://login.microsoftonline.com/%s/v2.0" .Values.app.oidc.entraid.tenantId }}
{{- else }}
{{- printf "https://keycloak.%s/realms/%s" .Values.global.localClusterDomain .Values.app.oidc.realm }}
{{- end }}
{{- end }}

{{/*
Generate the JWT Audience for SPIFFE authentication
*/}}
{{- define "qtodo.jwt.audience" }}
{{- if .Values.app.vault.audience }}
{{- print .Values.app.vault.audience }}
{{- else if eq .Values.app.oidc.provider "entraid" }}
{{- if .Values.app.oidc.entraid.audience }}
{{- print .Values.app.oidc.entraid.audience }}
{{- else if not .Values.app.oidc.clientId }}
{{- fail "app.oidc.clientId is required when using Entra ID provider without explicit audience" }}
{{- else }}
{{- printf "api://%s" .Values.app.oidc.clientId }}
{{- end }}
{{- else }}
{{- printf "https://keycloak.%s/realms/%s" .Values.global.localClusterDomain .Values.app.oidc.realm }}
{{- end }}
{{- end }}