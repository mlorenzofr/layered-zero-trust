{{/*
Create the image path for the passed in image field
*/}}
{{- define "qtodo.image" -}}
{{- if eq (substr 0 7 (tpl .value.version .context)) "sha256:" -}}
{{- printf "%s@%s" (tpl .value.name .context) (tpl .value.version .context) -}}
{{- else -}}
{{- printf "%s:%s" (tpl .value.name .context) (tpl .value.version .context) -}}
{{- end -}}
{{- end -}}

{{/*
Generate registry address
*/}}
{{- define "registry.address" }}
{{- if not .Values.registry.domain }}
{{- printf "quay-registry-quay-quay-enterprise.%s/%s" .Values.global.hubClusterDomain .Values.registry.org }}
{{- else }}
{{- printf "%s/%s" .Values.registry.domain .Values.registry.org }}
{{- end }}
{{- end }}

{{/*
Generate OIDC issuer
*/}}
{{- define "rhtas.oidc.issuer" }}
{{- if not .Values.rhtas.oidc.enabled }}
{{- printf "https://spire-spiffe-oidc-discovery-provider.%s" .Values.global.hubClusterDomain }}
{{- else }}
{{- print .Values.rhtas.oidc.issuer }}
{{- end }}
{{- end }}

{{/*
Generate OIDC identity
*/}}
{{- define "rhtas.oidc.identity" }}
{{- if not .Values.rhtas.oidc.enabled }}
{{- printf "spiffe://%s/ns/%s/sa/pipeline" .Values.global.hubClusterDomain .Values.global.namespace }}
{{- else }}
{{- print .Values.rhtas.oidc.identity }}
{{- end }}
{{- end }}

{{/*
Generate the RHTPA URL
*/}}
{{- define "rhtpa.url" }}
{{- if not .Values.rhtpa.url }}
{{- printf "https://servertrustify.%s" .Values.global.hubClusterDomain }}
{{- else }}
{{- print .Values.rhtpa.url }}
{{- end }}
{{- end }}

{{/*
Generate the URL of the OIDC service used by RHTPA
*/}}
{{- define "rhtpa.oidc.url" }}
{{- if not .Values.rhtpa.oidc.url }}
{{- printf "https://keycloak.%s/realms/%s" .Values.global.hubClusterDomain .Values.rhtpa.oidc.realm }}
{{- else }}
{{- print .Values.rhtpa.oidc.url }}
{{- end }}
{{- end }}