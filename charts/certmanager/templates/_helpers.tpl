{{- /*
  Validations for the acme issuer
*/ -}}
{{- define "acme.validations" -}}
{{- if and .Values.certmgrOperator .Values.certmgrOperator.issuers }}
{{- range $issuer, $properties := .Values.certmgrOperator.issuers }}
{{- if eq $issuer "acme" }}
{{- if not (or $properties.solvers $properties.aws $properties.azure $properties.gcp) }}
{{- fail "For the acme issuer, you must specify at least one of the properties solvers, aws, azure or gcp" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}